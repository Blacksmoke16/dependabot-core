# typed: false
# frozen_string_literal: true

require "spec_helper"
require "dependabot/source"
require "dependabot/dependency_file"
require "dependabot/shards/file_parser"
require_common_spec "file_parsers/shared_examples_for_file_parsers"

RSpec.describe Dependabot::Shards::FileParser do
  let(:files) { project_dependency_files(project_name) }
  let(:project_name) { "simple" }
  let(:parser) { described_class.new(dependency_files: files, source: source) }
  let(:source) do
    Dependabot::Source.new(
      provider: "github",
      repo: "crystal-lang/shards",
      directory: "/"
    )
  end

  it_behaves_like "a dependency file parser"

  describe "parse" do
    subject(:dependencies) { parser.parse }

    its(:length) { is_expected.to eq(2) }

    context "with a version specified" do
      describe "the first dependency" do
        subject { dependencies[0] }

        it { is_expected.to be_a(Dependabot::Dependency) }
        its(:name) { is_expected.to eq("openssl") }
        its(:version) { is_expected.to eq("1.2.3") }

        its(:requirements) do
          is_expected.to eq(
            [{
              requirement: nil,
              file: "shard.yml",
              groups: ["runtime"],
              source: {
                branch: nil,
                ref: nil,
                type: "git",
                url: "https://github.com/datanoise/openssl.cr.git"
              }
            }]
          )
        end
      end

      describe "the second dependency" do
        subject { dependencies[1] }

        it { is_expected.to be_a(Dependabot::Dependency) }
        its(:name) { is_expected.to eq("db") }
        its(:version) { is_expected.to eq("0.13.1") }

        its(:requirements) do
          is_expected.to eq(
            [{
              requirement: "~> 0.13.0",
              file: "shard.yml",
              groups: ["runtime"],
              source: {
                branch: nil,
                ref: nil,
                type: "git",
                url: "https://github.com/crystal-lang/crystal-db.git"
              }
            }]
          )
        end
      end
    end

    context "with a commit specified" do
      let(:project_name) { "commit_source" }

      describe "the first dependency" do
        subject { dependencies[0] }

        it { is_expected.to be_a(Dependabot::Dependency) }
        its(:name) { is_expected.to eq("db") }
        its(:version) { is_expected.to eq("1d0105ffeb1f983fafdda7ec2fd68916f74b4a4c") }

        its(:requirements) do
          is_expected.to eq(
            [{
              requirement: nil,
              file: "shard.yml",
              groups: ["runtime"],
              source: {
                branch: nil,
                ref: "1d0105ffeb1f983fafdda7ec2fd68916f74b4a4c",
                type: "git",
                url: "https://github.com/crystal-lang/crystal-db.git"
              }
            }]
          )
        end
      end
    end

    context "with a branch specified" do
      let(:project_name) { "branch_source" }

      describe "the first dependency" do
        subject { dependencies[0] }

        it { is_expected.to be_a(Dependabot::Dependency) }
        its(:name) { is_expected.to eq("db") }
        its(:version) { is_expected.to eq("3eaac85a5d4b7bee565b55dcb584e84e29fc5567") }

        its(:requirements) do
          is_expected.to eq(
            [{
              requirement: nil,
              file: "shard.yml",
              groups: ["runtime"],
              source: {
                branch: "master",
                ref: nil,
                type: "git",
                url: "https://github.com/crystal-lang/crystal-db.git"
              }
            }]
          )
        end
      end
    end

    context "with a tag specified" do
      let(:project_name) { "tag_source" }

      describe "the first dependency" do
        subject { dependencies[0] }

        it { is_expected.to be_a(Dependabot::Dependency) }
        its(:name) { is_expected.to eq("db") }
        its(:version) { is_expected.to eq("7fff589e026412646b33cef80f78cd1c7fd072aa") }

        its(:requirements) do
          is_expected.to eq(
            [{
              requirement: nil,
              file: "shard.yml",
              groups: ["runtime"],
              source: {
                branch: nil,
                ref: "v0.13.0",
                type: "git",
                url: "https://github.com/crystal-lang/crystal-db.git"
              }
            }]
          )
        end
      end
    end

    context "with gitlab source" do
      subject { dependencies[0] }

      let(:project_name) { "gitlab_source" }

      it { is_expected.to be_a(Dependabot::Dependency) }
      its(:name) { is_expected.to eq("spectator") }
      its(:version) { is_expected.to be_nil }

      its(:requirements) do
        is_expected.to eq(
          [{
            requirement: "~> 0.12.0",
            file: "shard.yml",
            groups: ["runtime"],
            source: {
              branch: nil,
              ref: nil,
              type: "git",
              url: "https://gitlab.com/arctic-fox/spectator.git"
            }
          }]
        )
      end
    end

    context "with bitbucket source" do
      subject { dependencies[0] }

      let(:project_name) { "bitbucket_source" }

      it { is_expected.to be_a(Dependabot::Dependency) }
      its(:name) { is_expected.to eq("test") }
      its(:version) { is_expected.to be_nil }

      its(:requirements) do
        is_expected.to eq(
          [{
            requirement: nil,
            file: "shard.yml",
            groups: ["runtime"],
            source: {
              branch: nil,
              ref: nil,
              type: "git",
              url: "https://bitbucket.com/org/test.git"
            }
          }]
        )
      end
    end

    context "with git source" do
      subject { dependencies[0] }

      let(:project_name) { "git_source" }

      it { is_expected.to be_a(Dependabot::Dependency) }
      its(:name) { is_expected.to eq("geoffrey") }
      its(:version) { is_expected.to be_nil }

      its(:requirements) do
        is_expected.to eq(
          [{
            requirement: nil,
            file: "shard.yml",
            groups: ["runtime"],
            source: {
              branch: nil,
              ref: nil,
              type: "git",
              url: "https://codeberg.org/skinnyjames/geoffrey.git"
            }
          }]
        )
      end
    end

    context "with a path dependency" do
      let(:project_name) { "path_source" }

      describe "the first dependency" do
        subject { dependencies.first }

        it { is_expected.to be_a(Dependabot::Dependency) }
        its(:name) { is_expected.to eq("test") }
        its(:version) { is_expected.to be_nil }

        its(:requirements) do
          is_expected.to eq(
            [{
              requirement: nil,
              file: "shard.yml",
              groups: ["runtime"],
              source: { type: "path" }
            }]
          )
        end
      end
    end

    context "with an unsupported lockfile source" do
      subject { dependencies[0] }

      let(:project_name) { "unsupported_source" }

      it { is_expected.to be_a(Dependabot::Dependency) }
      its(:name) { is_expected.to eq("fossil") }
      its(:version) { is_expected.to be_nil }

      its(:requirements) do
        is_expected.to eq(
          [{
            requirement: nil,
            file: "shard.yml",
            groups: ["runtime"],
            source: nil
          }]
        )
      end
    end

    context "with development dependencies" do
      subject { dependencies.first }

      let(:project_name) { "development_dependencies" }

      it "includes development dependencies" do
        expect(dependencies.length).to eq(1)
      end

      it { is_expected.to be_a(Dependabot::Dependency) }
      its(:name) { is_expected.to eq("db") }
      its(:version) { is_expected.to eq("0.13.1") }

      its(:requirements) do
        is_expected.to eq(
          [{
            requirement: "~> 0.13.0",
            file: "shard.yml",
            groups: ["development"],
            source: {
              branch: nil,
              ref: nil,
              type: "git",
              url: "https://github.com/crystal-lang/crystal-db.git"
            }
          }]
        )
      end
    end

    context "with subdependencies" do
      let(:project_name) { "development_subdependencies" }

      its(:length) { is_expected.to eq(4) }

      describe "top level dependencies" do
        subject { dependencies.select(&:top_level?) }

        its(:length) { is_expected.to eq(2) }
      end

      describe "a production subdependency" do
        subject(:subdep) do
          dependencies.find { |d| d.name == "db" }
        end

        it "parses the details correctly" do
          expect(subdep.version).to eq("0.13.1")
          expect(subdep.subdependency_metadata).to be_nil
        end
      end

      describe "a development subdependency" do
        subject(:subdep) do
          dependencies.find { |d| d.name == "pool" }
        end

        it "parses the details correctly" do
          expect(subdep.version).to eq("0.2.4")
          expect(subdep.subdependency_metadata).to be_nil
        end
      end
    end
  end

  describe "#ecosystem" do
    subject(:ecosystem) { parser.ecosystem }

    it "has the correct name" do
      expect(ecosystem.name).to eq "crystal"
    end

    describe "#package_manager" do
      subject(:package_manager) { ecosystem.package_manager }

      it "returns the correct package manager" do
        expect(package_manager.name).to eq "shards"
        expect(package_manager.requirement).to be_nil
        expect(package_manager.version.to_s).to eq "0.19.1"
      end
    end
  end
end
