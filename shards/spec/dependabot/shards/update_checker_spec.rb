# typed: false
# frozen_string_literal: true

require "spec_helper"

require "dependabot/shards"
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
        expect(updated_requirements.first[:requirement]).to eq("0.13.1")
      end
    end
  end

  it_behaves_like "a dependency that needs manifest changes to get updated"

  context "when there's no lockfile" do
    let(:project_name) { "no_lockfile" }

    it_behaves_like "a dependency that needs manifest changes to get updated"
  end

  describe "#lowest_security_fix_version" do
    subject(:lowest_security_fix_version) { checker.lowest_security_fix_version }

    let(:project_name) { "exact_version" }
    let(:name) { "db" }

    let(:security_advisories) do
      [
        Dependabot::SecurityAdvisory.new(
          dependency_name: name,
          package_manager: Dependabot::Shards::PackageManager::NAME,
          vulnerable_versions: ["<= 0.10.0"]
        )
      ]
    end

    context "when a supported newer version is available" do
      it "updates to the least new supported version" do
        expect(lowest_security_fix_version).to eq(Dependabot::Shards::Version.new("0.10.1"))
      end
    end

    context "with ignored versions" do
      let(:ignored_versions) { ["= 0.10.1"] }

      it "doesn't return ignored versions" do
        expect(lowest_security_fix_version).to eq(Dependabot::Shards::Version.new("0.11.0"))
      end
    end
  end

  describe "#lowest_resolvable_security_fix_version" do
    subject(:lowest_resolvable_security_fix_version) { checker.lowest_resolvable_security_fix_version }

    context "when a supported newer version is available, and resolvable" do
      let(:project_name) { "exact_version" }
      let(:name) { "db" }

      let(:security_advisories) do
        [
          Dependabot::SecurityAdvisory.new(
            dependency_name: name,
            package_manager: Dependabot::Shards::PackageManager::NAME,
            vulnerable_versions: ["<= 0.10.0"]
          )
        ]
      end

      it "updates to the least new supported version" do
        expect(lowest_resolvable_security_fix_version).to eq(Dependabot::Shards::Version.new("0.10.1"))
      end

      context "with ignored versions" do
        let(:ignored_versions) { ["= 0.10.0"] }

        it "doesn't return ignored versions" do
          expect(lowest_resolvable_security_fix_version).to eq(Dependabot::Shards::Version.new("0.10.1"))
        end
      end
    end
  end

  describe "#unlocked_requirements" do
    subject(:unlocked_requirements) { checker.send(:unlocked_requirements) }

    context "when dependency has a version" do
      let(:project_name) { "simple" }
      let(:name) { "db" }

      it "returns requirements with >= current version" do
        expect(unlocked_requirements).to be_an(Array)
        expect(unlocked_requirements.first).to include(requirement: ">= #{dependency.version}")
      end
    end

    context "when dependency has no version (no lockfile scenario)" do
      let(:project_name) { "simple" }
      let(:name) { "db" }
      let(:dependency) do
        Dependabot::Dependency.new(
          name: name,
          version: nil,
          requirements: [
            {
              requirement: "~> 0.10.0",
              groups: [],
              file: "shard.yml",
              source: {
                type: "git",
                url: "https://github.com/crystal-lang/crystal-db.git",
                ref: "0.10.0",
                branch: nil
              }
            }
          ],
          package_manager: "shards"
        )
      end

      it "returns requirements with wildcard (*) when version is nil" do
        expect(unlocked_requirements).to be_an(Array)
        expect(unlocked_requirements.first).to include(requirement: "*")
      end

      it "preserves other requirement properties" do
        unlocked_req = unlocked_requirements.first
        original_req = dependency.requirements.first

        expect(unlocked_req[:groups]).to eq(original_req[:groups])
        expect(unlocked_req[:file]).to eq(original_req[:file])
        expect(unlocked_req[:source]).to eq(original_req[:source])
      end
    end
  end
end
