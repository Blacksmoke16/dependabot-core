# typed: false
# frozen_string_literal: true

require "spec_helper"
require "dependabot/shards/file_updater/lockfile_updater"
require "dependabot/shards/package_manager"
require "dependabot/dependency_file"
require "dependabot/dependency"

RSpec.describe Dependabot::Shards::FileUpdater::LockfileUpdater do
  let(:updater) do
    described_class.new(
      dependency: dependency,
      manifest: manifest,
      repo_contents_path: repo_contents_path,
      credentials: credentials,
      allow_error: allow_error
    )
  end

  let(:dependency) do
    Dependabot::Dependency.new(
      name: "db",
      version: "0.13.1",
      previous_version: "0.10.0",
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
          version: ~> 0.13.0
    CONTENT
  end

  let(:repo_contents_path) { build_tmp_repo("simple") }
  let(:credentials) { [] }
  let(:allow_error) { true }

  describe "#updated_lockfile_content" do
    subject(:updated_lockfile_content) { updater.updated_lockfile_content }

    it "returns updated lockfile content" do
      expect(updated_lockfile_content).to be_a(String)
    end

    it "caches the result" do
      expect(updater.updated_lockfile_content).to equal(updater.updated_lockfile_content)
    end

    context "when shards command fails" do
      before do
        allow(Dependabot::Shards::Utils).to receive(:run_shards_command)
          .and_raise(Dependabot::SharedHelpers::HelperSubprocessFailed.new(
            message: "Shards command failed",
            error_context: {}
          ))
      end

      it "logs the error but continues" do
        expect { updated_lockfile_content }.not_to raise_error
      end

      it "returns lockfile content even after command failure" do
        expect(updated_lockfile_content).to be_a(String)
      end
    end
  end

  describe "allow_error parameter" do
    let(:helper_error) do
      Dependabot::SharedHelpers::HelperSubprocessFailed.new(
        message: "Shards install failed: Could not resolve dependency",
        error_context: {}
      )
    end

    before do
      allow(Dependabot::Shards::Utils).to receive(:run_shards_command)
        .with("lock --update db", fingerprint: "shards lock --update <dependency_name>")
        .and_raise(helper_error)
    end

    context "when allow_error is true (default)" do
      let(:allow_error) { true }

      it "logs the error but does not raise exception" do
        expect { updater.updated_lockfile_content }.not_to raise_error
      end

      it "returns lockfile content even when update fails" do
        expect(updater.updated_lockfile_content).to be_a(String)
      end
    end

    context "when allow_error is false" do
      let(:allow_error) { false }

      it "logs the error and raises the exception" do
        expect { updater.updated_lockfile_content }.to raise_error(
          Dependabot::SharedHelpers::HelperSubprocessFailed,
          "Shards install failed: Could not resolve dependency"
        )
      end
    end

    context "when no allow_error parameter is provided" do
      let(:updater_without_allow_error) do
        described_class.new(
          dependency: dependency,
          manifest: manifest,
          repo_contents_path: repo_contents_path,
          credentials: credentials
        )
      end

      it "defaults to allow_error: true" do
        expect { updater_without_allow_error.updated_lockfile_content }.not_to raise_error
      end
    end
  end
end
