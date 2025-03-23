# typed: false
# frozen_string_literal: true

require "spec_helper"
require "dependabot/dependency"
require "dependabot/dependency_file"
require "dependabot/shards/file_updater"
require_common_spec "file_updaters/shared_examples_for_file_updaters"

RSpec.describe Dependabot::Shards::FileUpdater do
  subject(:updater) do
    described_class.new(
      dependency_files: files,
      dependencies: dependencies,
      credentials: credentials,
      repo_contents_path: repo_contents_path
    )
  end

  let(:credentials) do
    [{ "type" => "git_source", "host" => "github.com", "username" => "x-access-token", "password" => "token" }]
  end
  let(:dependencies) { [] }
  let(:files) { project_dependency_files(project_name) }
  let(:repo_contents_path) { build_tmp_repo(project_name) }
  let(:project_name) { "simple" }

  it_behaves_like "a dependency file updater"

  describe "#updated_files_regex" do
    subject(:updated_files_regex) { described_class.updated_files_regex }

    it "is not empty" do
      expect(updated_files_regex).not_to be_empty
    end

    context "when files match the regex patterns" do
      it "returns true for files that should be updated" do
        matching_files = %w(shard.yml shard.lock).freeze

        matching_files.each do |file_name|
          expect(updated_files_regex).to(be_any { |regex| file_name.match?(regex) })
        end
      end

      it "returns false for files that should not be updated" do
        non_matching_files = [
          "shard.yaml",
          "README.md",
          ".github/workflow/main.yml",
          "some_random_file.rb",
          "package-lock.json",
          "package.json",
          "Gemfile",
          "Gemfile.lock"
        ]

        non_matching_files.each do |file_name|
          expect(updated_files_regex).not_to(be_any { |regex| file_name.match?(regex) })
        end
      end
    end
  end

  describe "#updated_dependency_files" do
    subject(:updated_dependency_files) { updater.updated_dependency_files }

    let(:dependencies) do
      [
        Dependabot::Dependency.new(
          name: "db",
          version: "0.13.1",
          previous_version: "0.10.0",
          requirements: [{
            requirement: "~> 0.13.0",
            groups: [],
            file: Dependabot::Shards::PackageManager::MANIFEST_FILENAME,
            source: {
              type: "git",
              url: "https://github.com/crystal-lang/crystal-db.git",
              ref: "0.10.0",
              branch: nil
            }
          }],
          previous_requirements: [{
            requirement: "~> 0.10.0",
            groups: [],
            file: Dependabot::Shards::PackageManager::MANIFEST_FILENAME,
            source: {
              type: "git",
              url: "https://github.com/crystal-lang/crystal-db.git",
              ref: "0.10.0",
              branch: nil
            }
          }],
          package_manager: Dependabot::Shards::PackageManager::NAME
        )
      ]
    end

    context "with three digit pin" do
      it "updates the version in manifest and lockfile" do
        manifest = updated_dependency_files.find do |file|
          file.name == Dependabot::Shards::PackageManager::MANIFEST_FILENAME
        end

        # Should not add a version to `openssl`
        expect(manifest.content).to include <<~RESOLVED
          dependencies:
            openssl:
              github: datanoise/openssl.cr
            db:
              github: crystal-lang/crystal-db
              version: ~> 0.13.0
        RESOLVED

        lockfile = updated_dependency_files.find do |file|
          file.name == Dependabot::Shards::PackageManager::LOCKFILE_FILENAME
        end

        expect(lockfile.content).to include <<~RESOLVED
          shards:
            openssl:
              git: https://github.com/datanoise/openssl.cr.git
              version: 1.2.3
            db:
              git: https://github.com/crystal-lang/crystal-db.git
              version: 0.13.1
        RESOLVED
      end
    end

    context "with two digit pin" do
      let(:project_name) { "two_digit_pin" }

      it "updates the version in manifest and lockfile" do
        manifest = updated_dependency_files.find do |file|
          file.name == Dependabot::Shards::PackageManager::MANIFEST_FILENAME
        end

        expect(manifest.content).to include(
          "    github: crystal-lang/crystal-db\n    version: ~> 0.10"
        )

        lockfile = updated_dependency_files.find do |file|
          file.name == Dependabot::Shards::PackageManager::LOCKFILE_FILENAME
        end

        expect(lockfile.content).to include <<~RESOLVED
          shards:
            db:
              git: https://github.com/crystal-lang/crystal-db.git
              version: 0.13.1
        RESOLVED
      end
    end

    # context "with specific commit" do
    #   let(:project_name) { "commit_source" }

    #   it "updates the version in manifest and lockfile" do
    #     manifest = updated_dependency_files
    #                .find { |file| file.name == Dependabot::Shards::PackageManager::MANIFEST_FILENAME }

    #     expect(manifest.content).to include(
    #       "    github: crystal-lang/crystal-db\n    version: ~> 0.10"
    #     )

    #     lockfile = updated_dependency_files
    #                .find { |file| file.name == Dependabot::Shards::PackageManager::LOCKFILE_FILENAME }

    #     expect(lockfile.content).to include <<~RESOLVED
    #       shards:
    #         db:
    #           git: https://github.com/crystal-lang/crystal-db.git
    #           version: 0.13.1
    #     RESOLVED
    #   end
    # end
  end
end
