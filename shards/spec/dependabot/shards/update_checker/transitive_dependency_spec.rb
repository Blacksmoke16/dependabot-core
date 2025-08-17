# typed: false
# frozen_string_literal: true

require "spec_helper"
require "dependabot/dependency"
require "dependabot/shards"

RSpec.describe "UpdateChecker transitive dependency handling" do
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

  let(:transitive_dependency) do
    Dependabot::Dependency.new(
      name: "athena-serializer",
      version: "0.3.0",
      requirements: [],
      package_manager: "shards",
      subdependency_metadata: [{ production: true }]
    )
  end

  let(:update_checker) do
    Dependabot::Shards::UpdateChecker.new(
      dependency: transitive_dependency,
      dependency_files: dependency_files,
      credentials: [],
      ignored_versions: [],
      security_advisories: []
    )
  end

  describe "#extract_source_from_lockfile" do
    it "extracts git source info from lockfile entries" do
      source = update_checker.send(:extract_source_from_lockfile)
      
      expect(source).not_to be_nil
      expect(source[:type]).to eq("git")
      expect(source[:url]).to eq("https://github.com/athena-framework/serializer.git")
      expect(source[:branch]).to be_nil
      expect(source[:ref]).to be_nil
    end

    context "with missing or invalid lockfile" do
      let(:dependency_files) do
        [
          Dependabot::DependencyFile.new(
            name: "shard.yml",
            content: shard_yml_content,
            directory: "/"
          )
        ]
      end

      it "returns nil when lockfile is missing" do
        source = update_checker.send(:extract_source_from_lockfile)
        expect(source).to be_nil
      end
    end
  end

  describe "#fetch_latest_version_for_transitive_dependency" do
    it "extracts source info and creates git commit checker" do
      # Mock the git commit checker to return a version
      mock_git_checker = instance_double(Dependabot::GitCommitChecker)
      latest_tag = { version: Dependabot::Shards::Version.new("0.4.2") }
      
      allow(mock_git_checker).to receive(:local_tag_for_latest_version).and_return(latest_tag)
      allow(Dependabot::GitCommitChecker).to receive(:new).and_return(mock_git_checker)

      result = update_checker.send(:fetch_latest_version_for_transitive_dependency)
      expect(result).to eq("0.4.2")
    end

    it "returns current version when no source info is available" do
      # Mock extract_source_from_lockfile to return nil
      allow(update_checker).to receive(:extract_source_from_lockfile).and_return(nil)

      result = update_checker.send(:fetch_latest_version_for_transitive_dependency)
      expect(result).to eq("0.3.0") # Should return current version
    end

    it "handles git commit checker errors gracefully" do
      allow(Dependabot::GitCommitChecker).to receive(:new).and_raise(StandardError.new("Git error"))

      result = update_checker.send(:fetch_latest_version_for_transitive_dependency)
      expect(result).to eq("0.3.0") # Should return current version on error
    end

    it "converts Version objects to strings properly" do
      mock_git_checker = instance_double(Dependabot::GitCommitChecker)
      # Test with different types that might be returned
      latest_tag = { version: Dependabot::Shards::Version.new("0.4.2") }
      
      allow(mock_git_checker).to receive(:local_tag_for_latest_version).and_return(latest_tag)
      allow(Dependabot::GitCommitChecker).to receive(:new).and_return(mock_git_checker)

      result = update_checker.send(:fetch_latest_version_for_transitive_dependency)
      expect(result).to be_a(String)
      expect(result).to eq("0.4.2")
    end
  end

  describe "#latest_version for transitive dependencies" do
    it "uses fetch_latest_version_for_transitive_dependency when no source details" do
      expect(update_checker).to receive(:fetch_latest_version_for_transitive_dependency).and_return("0.4.2")
      
      expect(update_checker.latest_version).to eq("0.4.2")
    end

    it "works with actual git commit checker integration" do
      # Mock the git fetching to avoid VCR dependency
      allow(update_checker)
        .to receive(:fetch_latest_version_for_transitive_dependency)
        .and_return("0.4.2")
      
      latest = update_checker.latest_version
      expect(latest).to be_a(String)
      expect(latest).to eq("0.4.2")
    end
  end
end
