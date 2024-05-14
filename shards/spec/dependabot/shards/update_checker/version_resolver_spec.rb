# typed: false
# frozen_string_literal: true

require "spec_helper"
require "dependabot/shards/update_checker/version_resolver"
require "dependabot/shards/package_manager"
require "dependabot/dependency_file"
require "dependabot/dependency"

RSpec.describe Dependabot::Shards::UpdateChecker::VersionResolver do
  let(:resolver) do
    described_class.new(
      dependency: dependency,
      manifest: manifest,
      lockfile: lockfile,
      repo_contents_path: repo_contents_path,
      credentials: credentials
    )
  end

  let(:dependency) do
    Dependabot::Dependency.new(
      name: "db",
      version: "0.10.0",
      requirements: [],
      package_manager: "shards"
    )
  end

  let(:manifest) do
    Dependabot::DependencyFile.new(
      name: "shard.yml",
      content: manifest_content,
      directory: "/"
    )
  end

  let(:manifest_content) do
    <<~CONTENT
      dependencies:
        db:
          github: crystal-lang/crystal-db
          version: ~> 0.10.0
    CONTENT
  end

  let(:lockfile) do
    Dependabot::DependencyFile.new(
      name: "shard.lock",
      content: lockfile_content,
      directory: "/"
    )
  end

  let(:lockfile_content) do
    <<~CONTENT
      version: 2.0
      shards:
        db:
          git: https://github.com/crystal-lang/crystal-db.git
          version: 0.10.0
    CONTENT
  end

  let(:repo_contents_path) { "/tmp/repo" }
  let(:credentials) { [] }

  describe "#latest_resolvable_version" do
    subject(:latest_resolvable_version) { resolver.latest_resolvable_version }

    before do
      allow(Dependabot::Shards::FileUpdater::LockfileUpdater).to receive(:new)
        .and_return(double(updated_lockfile_content: updated_lockfile_content))
    end

    context "when lockfile can be updated successfully" do
      let(:updated_lockfile_content) do
        <<~CONTENT
          version: 2.0
          shards:
            db:
              git: https://github.com/crystal-lang/crystal-db.git
              version: 0.13.1
        CONTENT
      end

      it "returns the new version from updated lockfile" do
        expect(latest_resolvable_version).to eq("0.13.1")
      end
    end

    context "when lockfile content is unchanged" do
      let(:updated_lockfile_content) { lockfile_content }

      it "returns nil when no update is possible" do
        expect(latest_resolvable_version).to be_nil
      end
    end

    context "when no lockfile exists initially" do
      let(:lockfile) { nil }
      let(:updated_lockfile_content) do
        <<~CONTENT
          version: 2.0
          shards:
            db:
              git: https://github.com/crystal-lang/crystal-db.git
              version: 0.13.1
        CONTENT
      end

      it "returns the version from newly generated lockfile" do
        expect(latest_resolvable_version).to eq("0.13.1")
      end
    end

    context "when updated lockfile has invalid YAML" do
      let(:updated_lockfile_content) { "invalid yaml content:\n  - malformed" }

      it "returns nil when YAML parsing fails" do
        expect(latest_resolvable_version).to be_nil
      end
    end

    context "when dependency is not in updated lockfile" do
      let(:updated_lockfile_content) do
        <<~CONTENT
          version: 2.0
          shards:
            other_dependency:
              git: https://github.com/example/other.git
              version: 1.0.0
        CONTENT
      end

      it "returns nil when dependency not found" do
        expect(latest_resolvable_version).to be_nil
      end
    end

    context "when shards section is missing from lockfile" do
      let(:updated_lockfile_content) do
        <<~CONTENT
          version: 2.0
        CONTENT
      end

      it "returns nil when shards section missing" do
        expect(latest_resolvable_version).to be_nil
      end
    end
  end
end