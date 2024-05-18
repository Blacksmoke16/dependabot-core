# typed: false
# frozen_string_literal: true

require "spec_helper"

require "dependabot/shards/update_checker"
require "dependabot/dependency_file"
require "dependabot/dependency"
require "dependabot/requirements_update_strategy"
require_common_spec "update_checkers/shared_examples_for_update_checkers"

RSpec.describe Dependabot::Shards::UpdateChecker do
  it_behaves_like "an update checker"

  let(:checker) do
    described_class.new(
      dependency: dependency,
      dependency_files: files,
      credentials: credentials,
      ignored_versions: ignored_versions,
      raise_on_ignored: raise_on_ignored,
      security_advisories: security_advisories,
      requirements_update_strategy: requirements_update_strategy
    )
  end

  let(:dependency) do
    Dependabot::Dependency.new(
      name: dependency_name,
      version: dependency_version,
      requirements: requirements,
      package_manager: "shards"
    )
  end
  let(:ignored_versions) { [] }
  let(:raise_on_ignored) { false }
  let(:security_advisories) { [] }
  let(:requirements_update_strategy) { nil }
  let(:dependency_name) { "db" }
  let(:dependency_version) { "0.10.0" }
  let(:requirements) do
    [{ file: "shard.yml", requirement: "0.10.0", groups: [], source: {
      type: "git",
      url: "https://github.com/crystal-lang/crystal-db.git",
      branch: nil,
      ref: nil
    }
  }]
  end
  let(:credentials) { github_credentials }
  let(:files) { project_dependency_files(project_name) }
  let(:project_name) { "exact_version" }

  describe "#latest_version" do
    subject { checker.latest_version }

    context "with a path source" do
      context "that is the dependency we're checking" do
        let(:dependency_name) { "db" }
        let(:dependency_version) { "0.10.0" }
        let(:requirements) do
          [{
            requirement: "0.10.0",
            file: "shard.yml",
            groups: ["dependencies"],
            source: { type: "path" }
          }]
        end

        it { is_expected.to be_nil }
      end
    end

    context "with a git source" do
      let(:service_pack_url) do
        "https://github.com/crystal-lang/crystal-db.git/info/refs" \
          "?service=git-upload-pack"
      end
      before do
        stub_request(:get, service_pack_url)
          .to_return(
            status: 200,
            body: fixture("git", "upload_packs", upload_pack_fixture),
            headers: {
              "content-type" => "application/x-git-upload-pack-advertisement"
            }
          )
      end
      let(:upload_pack_fixture) { "db" }

      context "when using default requirement" do
        let(:dependency_version) { "0.10.0" }
        let(:requirements) do
          [{
            requirement: nil,
            file: "shard.yml",
            groups: ["dependencies"],
            source: {
              type: "git",
              url: "https://github.com/crystal-lang/crystal-db.git",
              branch: nil,
              ref: nil
            }
          }]
        end

        # Should use latest tag
        it { is_expected.to eq(Gem::Version.new("0.13.1")) }
      end

      context "when pinned to a specific commit" do
        let(:project_name) { "commit_source" }

        let(:dependency_version) { "1d0105ffeb1f983fafdda7ec2fd68916f74b4a4c" }
        let(:requirements) do
          [{
            requirement: nil,
            file: "shard.yml",
            groups: ["dependencies"],
            source: {
              type: "git",
              url: "https://github.com/crystal-lang/crystal-db.git",
              branch: nil,
              ref: "1d0105ffeb1f983fafdda7ec2fd68916f74b4a4c"
            }
          }]
        end

        # Should remain unchanged
        it { is_expected.to eq("1d0105ffeb1f983fafdda7ec2fd68916f74b4a4c") }
      end

      context "when pinned to a specific branch" do
        let(:project_name) { "branch_source" }

        let(:dependency_version) { "7fff589e026412646b33cef80f78cd1c7fd072aa" }
        let(:requirements) do
          [{
            requirement: nil,
            file: "shard.yml",
            groups: ["dependencies"],
            source: {
              type: "git",
              url: "https://github.com/crystal-lang/crystal-db.git",
              branch: "master",
              ref: nil
            }
          }]
        end

        # Should use latest commit on the branch
        it { is_expected.to eq("3eaac85a5d4b7bee565b55dcb584e84e29fc5567") }
      end

      context "when pinned to a specific tag" do
        let(:project_name) { "tag_source" }

        let(:dependency_version) { "0.13.0" }
        let(:requirements) do
          [{
            requirement: nil,
            file: "shard.yml",
            groups: ["dependencies"],
            source: {
              type: "git",
              url: "https://github.com/crystal-lang/crystal-db.git",
              branch: nil,
              ref: "v0.13.0"
            }
          }]
        end

        # Should use latest tag
        it { is_expected.to eq(Gem::Version.new("0.13.1")) }
      end
    end
  end
end
