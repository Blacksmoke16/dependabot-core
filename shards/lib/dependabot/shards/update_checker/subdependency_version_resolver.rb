# typed: true
# frozen_string_literal: true

require "dependabot/dependency"
require "dependabot/errors"
require "dependabot/logger"
require "dependabot/shared_helpers"
require "dependabot/shards/utils"
require "dependabot/shards/version"

module Dependabot
  module Shards
    class UpdateChecker
      class SubdependencyVersionResolver
        extend T::Sig

        sig { returns(Dependency) }
        attr_reader :dependency

        sig { returns(T::Array[Dependabot::Credential]) }
        attr_reader :credentials

        sig { returns(T::Array[Dependabot::DependencyFile]) }
        attr_reader :dependency_files

        sig { returns(T::Array[String]) }
        attr_reader :ignored_versions

        sig { returns(T.nilable(T.any(String, Gem::Version))) }
        attr_reader :latest_allowable_version

        sig { returns(T.nilable(String)) }
        attr_reader :repo_contents_path

        sig do
          params(
            dependency: Dependency,
            credentials: T::Array[Dependabot::Credential],
            dependency_files: T::Array[Dependabot::DependencyFile],
            ignored_versions: T::Array[String],
            latest_allowable_version: T.nilable(T.any(String, Gem::Version)),
            repo_contents_path: T.nilable(String)
          ).void
        end
        def initialize(dependency:, credentials:, dependency_files:,
                       ignored_versions:, latest_allowable_version:, repo_contents_path:)
          @dependency = dependency
          @credentials = credentials
          @dependency_files = dependency_files
          @ignored_versions = ignored_versions
          @latest_allowable_version = latest_allowable_version
          @repo_contents_path = repo_contents_path
        end

        sig { returns(T.nilable(T.any(String, Gem::Version))) }
        def latest_resolvable_version
          raise "Not a subdependency!" if dependency.requirements.any?

          # First try to get the actual latest version from the git repository
          actual_latest = fetch_latest_version_from_git
          return actual_latest if actual_latest

          # Fallback to lockfile resolution approach
          base_dir = T.must(dependency_files.first).directory
          SharedHelpers.in_a_temporary_repo_directory(base_dir, repo_contents_path) do
            write_temporary_dependency_files

            updated_lockfile_content = update_subdependency_in_lockfile
            return unless updated_lockfile_content

            version_from_updated_lockfile(updated_lockfile_content)
          end
        rescue SharedHelpers::HelperSubprocessFailed => e
          Dependabot.logger.error("Failed to resolve subdependency version: #{e.message}")
          nil
        end

        private

        sig { returns(T.nilable(String)) }
        def fetch_latest_version_from_git
          # Get source details from lockfile
          lockfile_source = extract_source_from_lockfile
          return unless lockfile_source

          # Create a temporary dependency with source details
          temp_dependency = Dependency.new(
            name: dependency.name,
            version: dependency.version,
            requirements: [{
              requirement: nil,
              file: "shard.lock",
              source: lockfile_source,
              groups: ["runtime"]
            }],
            package_manager: dependency.package_manager
          )

          # Use git commit checker to find the actual latest version
          git_checker = Dependabot::GitCommitChecker.new(
            dependency: temp_dependency,
            credentials: credentials,
            ignored_versions: ignored_versions
          )

          latest_tag = git_checker.local_tag_for_latest_version
          return unless latest_tag
          
          version = latest_tag.fetch(:version)
          version.respond_to?(:to_s) ? version.to_s : version
        rescue StandardError => e
          Dependabot.logger.debug("Failed to fetch latest version from git: #{e.message}")
          nil
        end

        sig { returns(T.nilable(T::Hash[Symbol, T.nilable(String)])) }
        def extract_source_from_lockfile
          lockfile = dependency_files.find { |f| f.name == "shard.lock" }
          return unless lockfile

          parsed_lockfile = YAML.safe_load(lockfile.content)
          details = parsed_lockfile&.dig("shards", dependency.name)
          return unless details

          git_url = details["git"]
          return unless git_url

          {
            type: "git",
            url: git_url,
            branch: nil,
            ref: nil
          }
        rescue StandardError => e
          Dependabot.logger.debug("Failed to extract source from lockfile: #{e.message}")
          nil
        end

        sig { returns(Dependabot::Shards::FileParser) }
        def file_parser
          @file_parser ||= begin
            require "dependabot/shards/file_parser"
            temp_source = Dependabot::Source.new(
              provider: "github",
              repo: "temp/repo",
              directory: T.must(dependency_files.first).directory
            )
            Dependabot::Shards::FileParser.new(
              dependency_files: dependency_files,
              source: temp_source
            )
          end
        end

        sig { returns(T.nilable(String)) }
        def update_subdependency_in_lockfile
          lockfile_path = "shard.lock"

          # Run shards install to update the lockfile with latest resolvable versions
          # This will respect the constraints in shard.yml while updating transitive deps
          output = Utils.run_shards_command("install", allow_failure: true)

          return unless File.exist?(lockfile_path)
          File.read(lockfile_path)
        rescue StandardError => e
          Dependabot.logger.error("Failed to update lockfile: #{e.message}")
          nil
        end

        sig { params(lockfile_content: String).returns(T.nilable(String)) }
        def version_from_updated_lockfile(lockfile_content)
          parsed_lockfile = YAML.safe_load(lockfile_content)
          dependency_info = parsed_lockfile.dig("shards", dependency.name)
          return unless dependency_info

          version = dependency_info["version"]
          return unless version.is_a?(String)

          # Handle git commit versions
          if version.include?("+git.commit")
            version.split("+git.commit.")[1]
          else
            version
          end
        rescue Psych::SyntaxError => e
          Dependabot.logger.error("Failed to parse updated lockfile: #{e.message}")
          nil
        end

        sig { void }
        def write_temporary_dependency_files
          dependency_files.each do |file|
            path = file.name
            FileUtils.mkdir_p(Pathname.new(path).dirname) if path.include?("/")
            File.write(path, file.content)
          end
        end
      end
    end
  end
end
