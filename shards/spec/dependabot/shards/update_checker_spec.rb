# typed: false
# frozen_string_literal: true

require "spec_helper"

require "dependabot/swift/file_parser"
require "dependabot/shards/update_checker"
require "dependabot/dependency_file"
require "dependabot/dependency"
require "dependabot/requirements_update_strategy"
require_common_spec "update_checkers/shared_examples_for_update_checkers"

RSpec.describe Dependabot::Shards::UpdateChecker do
  let(:dependency) { dependencies.find { |dep| dep.name == name } }
  let(:file_parser) do
    Dependabot::Shards::FileParser.new(
      dependency_files: dependency_files,
      repo_contents_path: repo_contents_path,
      source: nil
    )
  end
  let(:dependencies) do
    file_parser.parse
  end
  let(:raise_on_ignored) { false }
  let(:ignored_versions) { [] }
  let(:security_advisories) { [] }
  let(:dependency_files) { project_dependency_files(project_name, directory: directory) }
  let(:repo_contents_path) { build_tmp_repo(project_name, path: "projects") }
  let(:directory) { "/" }
  let(:upload_pack_fixture) { "db" }
  let(:service_pack_url) do
    "https://github.com/crystal-lang/crystal-db.git/info/refs" \
      "?service=git-upload-pack"
  end
  let(:checker) do
    described_class.new(
      dependency: dependency,
      dependency_files: dependency_files,
      repo_contents_path: repo_contents_path,
      credentials: github_credentials,
      security_advisories: security_advisories,
      ignored_versions: ignored_versions,
      raise_on_ignored: raise_on_ignored
    )
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

  it_behaves_like "an update checker"

  context "with an up to date dependency" do
    let(:project_name) { "up_to_date" }
    let(:name) { "db" }

    describe "#can_update?" do
      subject { checker.can_update?(requirements_to_unlock: :own) }

      it { is_expected.to be_falsey }
    end

    describe "#latest_version" do
      subject { checker.latest_version }

      it { is_expected.to eq(dependency.version) }
    end

    describe "#latest_resolvable_version" do
      subject { checker.latest_resolvable_version }

      it { is_expected.to eq(dependency.version) }
    end
  end

  context "with a dependency that needs only lockfile changes to get updated" do
    let(:project_name) { "only_lockfile_change" }
    let(:name) { "db" }

    describe "#can_update?" do
      subject { checker.can_update?(requirements_to_unlock: :own) }

      it { is_expected.to be_truthy }
    end

    describe "#latest_version" do
      subject { checker.latest_version }

      it { is_expected.to eq("0.13.1") }
    end

    describe "#latest_resolvable_version" do
      subject { checker.latest_resolvable_version }

      it { is_expected.to eq("0.13.1") }
    end

    describe "#updated_requirements" do
      subject(:updated_requirements) { checker.updated_requirements }

      it "does not update them" do
        expect(updated_requirements.first[:requirement]).to eq("~> 0.13.0")
      end
    end
  end

  shared_examples_for "a dependency that needs manifest changes to get updated" do
    let(:project_name) { "exact_version" }
    let(:name) { "db" }

    describe "#can_update?" do
      subject { checker.can_update?(requirements_to_unlock: :own) }

      it { is_expected.to be_truthy }
    end

    describe "#latest_version" do
      subject { checker.latest_version }

      it { is_expected.to eq("0.13.1") }
    end

    describe "#latest_resolvable_version" do
      subject { checker.latest_resolvable_version }

      it { is_expected.to eq("0.13.1") }
    end

    describe "#updated_requirements" do
      subject(:updated_requirements) { checker.updated_requirements }

      it "updates them to match new version" do
        expect(updated_requirements.first[:requirement]).to eq("~> 0.13.0")
      end
    end
  end

  # it_behaves_like "a dependency that needs manifest changes to get updated"

  describe "#latest_version" do
    subject(:latest_version) { checker.latest_version }

    let(:project_name) { "exact_version" }
    let(:name) { "db" }

    context "with a path source" do
      let(:project_name) { "path_source" }
      let(:name) { "test" }

      it { is_expected.to be_nil }
    end

    context "with a git source" do
      context "when the user is ignoring the latest version" do
        let(:ignored_versions) { [">= 0.13.0"] }

        it { is_expected.to eq(Gem::Version.new("0.12.0")) }
      end

      context "when the user is ignoring all versions" do
        let(:ignored_versions) { [">= 0"] }

        it "returns latest_resolvable_version" do
          expect(latest_version).to be_nil
        end

        context "when raise_on_ignored is enabled" do
          let(:raise_on_ignored) { true }

          it "raises an error" do
            expect { latest_version }.to raise_error(Dependabot::AllVersionsIgnored)
          end
        end
      end

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

        # Should use the latest tag
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
        it { is_expected.to eq(dependency_version) }
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

        # Should use commit of latest tag
        it { is_expected.to eq(Gem::Version.new("0.13.1")) }
      end
    end
  end

  describe "#lowest_security_fix_version" do
    subject(:lowest_security_fix_version) { checker.lowest_security_fix_version }

    let(:project_name) { "exact_version" }
    let(:name) { "db" }

    it "finds the lowest available non-vulnerable version" do
      expect(lowest_security_fix_version).to eq(Gem::Version.new("0.10.1"))
    end

    context "with a security vulnerability" do
      let(:security_advisories) do
        [
          Dependabot::SecurityAdvisory.new(
            dependency_name: name,
            package_manager: "shards",
            vulnerable_versions: ["<= 0.10.0"]
          )
        ]
      end

      it "finds the lowest available non-vulnerable version" do
        expect(lowest_security_fix_version).to eq(Gem::Version.new("0.10.1"))
      end
    end
  end
end
