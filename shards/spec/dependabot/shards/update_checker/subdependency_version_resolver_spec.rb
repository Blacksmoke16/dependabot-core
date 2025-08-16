# typed: false
# frozen_string_literal: true

require "spec_helper"
require "dependabot/dependency"
require "dependabot/shards/update_checker/subdependency_version_resolver"

RSpec.describe Dependabot::Shards::UpdateChecker::SubdependencyVersionResolver do
  subject(:resolver) do
    described_class.new(
      dependency: dependency,
      credentials: credentials,
      dependency_files: dependency_files,
      ignored_versions: ignored_versions,
      latest_allowable_version: latest_allowable_version,
      repo_contents_path: repo_contents_path
    )
  end

  let(:credentials) { [] }
  let(:ignored_versions) { [] }
  let(:latest_allowable_version) { nil }
  let(:repo_contents_path) { nil }

  let(:dependency_files) do
    [
      Dependabot::DependencyFile.new(
        name: "shard.yml",
        content: shard_yml_content,
        directory: "/"
      ),
      Dependabot::DependencyFile.new(
        name: "shard.lock",
        content: shard_lock_content,
        directory: "/"
      )
    ]
  end

  let(:shard_yml_content) do
    <<~YAML
      name: test_app
      version: 0.1.0

      dependencies:
        athena:
          github: athena-framework/framework
          version: ~> 0.20.0
    YAML
  end

  let(:shard_lock_content) do
    <<~YAML
      version: 2.0
      shards:
        athena:
          git: https://github.com/athena-framework/framework.git
          version: 0.20.1

        athena-serializer:
          git: https://github.com/athena-framework/serializer.git
          version: 0.3.0
    YAML
  end
  let(:dependency) do
    Dependabot::Dependency.new(
      name: "athena-serializer",
      version: "0.3.0",
      requirements: [],
      package_manager: "shards",
      subdependency_metadata: [{ production: true }]
    )
  end

  describe "#latest_resolvable_version" do
    context "with a transitive dependency" do
      before do
        allow(File).to receive(:exist?).and_call_original
        allow(File).to receive(:read).and_call_original
        allow(FileUtils).to receive(:mkdir_p).and_call_original
        allow(File).to receive(:write).and_call_original
      end

      it "returns the latest resolvable version" do
        allow(Dependabot::Shards::Utils)
          .to receive(:run_shards_command)
          .with("install", allow_failure: true)
          .and_return("Installing dependencies...")

        # Mock the updated lockfile content
        updated_lockfile_content = <<~LOCKFILE
          version: 2.0
          shards:
            athena-serializer:
              git: https://github.com/athena-framework/serializer.git
              version: 0.4.2
        LOCKFILE

        allow(File).to receive(:exist?).with("shard.lock").and_return(true)
        allow(File).to receive(:read).with("shard.lock").and_return(updated_lockfile_content)

        expect(resolver.latest_resolvable_version).to eq("0.4.2")
      end

      it "handles git commit versions" do
        allow(Dependabot::Shards::Utils)
          .to receive(:run_shards_command)
          .with("install", allow_failure: true)
          .and_return("Installing dependencies...")

        # Mock lockfile with git commit version
        updated_lockfile_content = <<~LOCKFILE
          version: 2.0
          shards:
            athena-serializer:
              git: https://github.com/athena-framework/serializer.git
              version: 0.4.2+git.commit.abc123
        LOCKFILE

        allow(File).to receive(:exist?).with("shard.lock").and_return(true)
        allow(File).to receive(:read).with("shard.lock").and_return(updated_lockfile_content)

        expect(resolver.latest_resolvable_version).to eq("abc123")
      end

      it "returns nil when shards install fails" do
        allow(Dependabot::Shards::Utils)
          .to receive(:run_shards_command)
          .with("install", allow_failure: true)
          .and_raise(StandardError.new("Failed to install"))

        expect(resolver.latest_resolvable_version).to be_nil
      end

      it "returns nil when lockfile doesn't contain the dependency" do
        allow(Dependabot::Shards::Utils)
          .to receive(:run_shards_command)
          .with("install", allow_failure: true)
          .and_return("Installing dependencies...")

        updated_lockfile_content = <<~LOCKFILE
          version: 2.0
          shards:
            other-dependency:
              git: https://github.com/other/repo.git
              version: 1.0.0
        LOCKFILE

        allow(File).to receive(:exist?).with("shard.lock").and_return(true)
        allow(File).to receive(:read).with("shard.lock").and_return(updated_lockfile_content)

        expect(resolver.latest_resolvable_version).to be_nil
      end

      it "returns nil when lockfile is invalid YAML" do
        allow(Dependabot::Shards::Utils)
          .to receive(:run_shards_command)
          .with("install", allow_failure: true)
          .and_return("Installing dependencies...")

        allow(File).to receive(:exist?).with("shard.lock").and_return(true)
        allow(File).to receive(:read).with("shard.lock").and_return("invalid: yaml: content [")

        expect(resolver.latest_resolvable_version).to be_nil
      end
    end

    context "with a direct dependency" do
      let(:dependency) do
        Dependabot::Dependency.new(
          name: "athena",
          version: "0.20.0",
          requirements: [{
            requirement: "~> 0.20.0",
            file: "shard.yml",
            source: { type: "git", url: "https://github.com/athena-framework/framework.git" },
            groups: ["runtime"]
          }],
          package_manager: "shards"
        )
      end

      it "raises an error for direct dependencies" do
        expect { resolver.latest_resolvable_version }.to raise_error("Not a subdependency!")
      end
    end
  end

  describe "#fetch_latest_version_from_git" do
    let(:dependency) do
      Dependabot::Dependency.new(
        name: "athena-serializer",
        version: "0.3.0",
        requirements: [],
        package_manager: "shards",
        subdependency_metadata: [{ production: true }]
      )
    end

    context "when git source is available in lockfile" do
      before do
        allow(resolver)
          .to receive(:extract_source_from_lockfile)
          .and_return({
            type: "git",
            url: "https://github.com/athena-framework/serializer.git",
            branch: nil,
            ref: nil
          })
      end

      it "creates git commit checker and returns latest version as string" do
        mock_git_checker = instance_double(Dependabot::GitCommitChecker)
        latest_tag = { version: Dependabot::Shards::Version.new("0.4.2") }
        
        allow(mock_git_checker).to receive(:local_tag_for_latest_version).and_return(latest_tag)
        allow(Dependabot::GitCommitChecker).to receive(:new).and_return(mock_git_checker)

        result = resolver.send(:fetch_latest_version_from_git)
        expect(result).to eq("0.4.2")
        expect(result).to be_a(String)
      end

      it "handles Version object to string conversion correctly" do
        mock_git_checker = instance_double(Dependabot::GitCommitChecker)
        latest_tag = { version: Dependabot::Shards::Version.new("1.2.3-beta") }
        
        allow(mock_git_checker).to receive(:local_tag_for_latest_version).and_return(latest_tag)
        allow(Dependabot::GitCommitChecker).to receive(:new).and_return(mock_git_checker)

        result = resolver.send(:fetch_latest_version_from_git)
        expect(result).to eq("1.2.3-beta")
        expect(result).to be_a(String)
      end

      it "returns nil when no latest tag is found" do
        mock_git_checker = instance_double(Dependabot::GitCommitChecker)
        allow(mock_git_checker).to receive(:local_tag_for_latest_version).and_return(nil)
        allow(Dependabot::GitCommitChecker).to receive(:new).and_return(mock_git_checker)

        result = resolver.send(:fetch_latest_version_from_git)
        expect(result).to be_nil
      end

      it "handles git commit checker creation errors" do
        allow(Dependabot::GitCommitChecker).to receive(:new).and_raise(StandardError.new("Git error"))

        result = resolver.send(:fetch_latest_version_from_git)
        expect(result).to be_nil
      end
    end

    context "when no git source is available" do
      before do
        allow(resolver)
          .to receive(:extract_source_from_lockfile)
          .and_return(nil)
      end

      it "returns nil when lockfile has no source info" do
        result = resolver.send(:fetch_latest_version_from_git)
        expect(result).to be_nil
      end
    end
  end

  describe "integration with actual git fetching" do
    let(:dependency) do
      Dependabot::Dependency.new(
        name: "athena-serializer",
        version: "0.3.0",
        requirements: [],
        package_manager: "shards",
        subdependency_metadata: [{ production: true }]
      )
    end

    it "prioritizes git fetching over lockfile resolution", :vcr do
      # Mock git fetching to return a specific version
      allow_any_instance_of(Dependabot::Shards::UpdateChecker::SubdependencyVersionResolver)
        .to receive(:fetch_latest_version_from_git)
        .and_return("0.4.2")

      # Mock lockfile resolution to return a different version
      allow_any_instance_of(Dependabot::Shards::UpdateChecker::SubdependencyVersionResolver)
        .to receive(:update_subdependency_in_lockfile)
        .and_return(shard_lock_content)

      result = resolver.latest_resolvable_version
      expect(result).to eq("0.4.2") # Should use git result, not lockfile
    end

    it "falls back to lockfile resolution when git fails" do
      allow_any_instance_of(Dependabot::Shards::UpdateChecker::SubdependencyVersionResolver)
        .to receive(:fetch_latest_version_from_git)
        .and_return(nil)

      # Mock the lockfile approach
      allow(Dependabot::Shards::Utils)
        .to receive(:run_shards_command)
        .with("install", allow_failure: true)
        .and_return("Installing...")

      updated_lockfile = <<~LOCKFILE
        version: 2.0
        shards:
          athena-serializer:
            git: https://github.com/athena-framework/serializer.git
            version: 0.4.1
      LOCKFILE

      allow(File).to receive(:exist?).with("shard.lock").and_return(true)
      allow(File).to receive(:read).with("shard.lock").and_return(updated_lockfile)

      result = resolver.latest_resolvable_version
      expect(result).to eq("0.4.1")
    end
  end
end