# typed: true
# frozen_string_literal: true

require "dependabot/shared_helpers"
require "dependabot/shards/update_checker"
require "dependabot/shards/file_parser"
require "dependabot/shards/version"
require "dependabot/errors"

module Dependabot
  module Shards
    class UpdateChecker
      class VersionResolver
        UNABLE_TO_UPDATE = /Unable to update (?<url>.*?)$/
        BRANCH_NOT_FOUND_REGEX = /#{UNABLE_TO_UPDATE}.*to find branch `(?<branch>[^`]+)`/m
        REVSPEC_PATTERN = /revspec '.*' not found/
        OBJECT_PATTERN = /object not found - no match for id \(.*\)/
        REF_NOT_FOUND_REGEX = /#{UNABLE_TO_UPDATE}.*(#{REVSPEC_PATTERN}|#{OBJECT_PATTERN})/m
        GIT_REF_NOT_FOUND_REGEX = /Updating git repository `(?<url>[^`]*)`.*fatal: couldn't find remote ref/m

        def initialize(dependency:, credentials:,
                       dependency_files:)
          @dependency = dependency
          @dependency_files = dependency_files
          @credentials = credentials
        end

        def latest_resolvable_version
          return @latest_resolvable_version if defined?(@latest_resolvable_version)

          @latest_resolvable_version = fetch_latest_resolvable_version
          rescue Dependabot::SharedHelpers::HelperSubprocessFailed => e
            raise Dependabot::DependencyFileNotResolvable, e.message
        end

        private

        attr_reader :dependency
        attr_reader :credentials
        attr_reader :dependency_files

        def fetch_latest_resolvable_version
          base_directory = dependency_files.first.directory
          SharedHelpers.in_a_temporary_directory(base_directory) do
            write_temporary_dependency_files

            SharedHelpers.with_git_configured(credentials: credentials) do
              run_shards_outdated_command
            end

            updated_version = fetch_version_from_new_lockfile

            # return if updated_version.nil?
            # return updated_version if git_dependency?

            # version_class.new(updated_version)
          end
        rescue SharedHelpers::HelperSubprocessFailed => e
          retry if better_specification_needed?(e)
          handle_cargo_errors(e)
        end

        def fetch_version_from_new_lockfile
          lockfile_content = File.read("shard.lock")
          versions = YAML.safe_load(lockfile_content).fetch("shards")
                           .select { |(k, _)| k == dependency.name }

          pp versions

          exit 0

          updated_version =
            if dependency.top_level?
              versions.max_by { |p| version_class.new(p.fetch("version")) }
            else
              versions.min_by { |p| version_class.new(p.fetch("version")) }
            end

          return unless updated_version

          if git_dependency?
            updated_version.fetch("source").split("#").last
          else
            updated_version.fetch("version")
          end
        end

        # rubocop:disable Metrics/PerceivedComplexity
        # rubocop:disable Metrics/CyclomaticComplexity
        # rubocop:disable Metrics/AbcSize
        def better_specification_needed?(error)
          return false if @custom_specification
          return false unless error.message.match?(/specification .* is ambigu/)

          spec_options = error.message.gsub(/.*following:\n/m, "")
                              .lines.map(&:strip)

          ver = if git_dependency? && git_dependency_version
                  git_dependency_version
                else
                  dependency.version
                end

          if spec_options.count { |s| s.end_with?(ver) } == 1
            @custom_specification = spec_options.find { |s| s.end_with?(ver) }
            return true
          elsif spec_options.count { |s| s.end_with?(ver) } > 1
            spec_options.select! { |s| s.end_with?(ver) }
          end

          if git_dependency? && git_source_url &&
             spec_options.count { |s| s.include?(git_source_url) } >= 1
            spec_options.select! { |s| s.include?(git_source_url) }
          end

          @custom_specification = spec_options.first
          true
        end
        # rubocop:enable Metrics/AbcSize
        # rubocop:enable Metrics/CyclomaticComplexity
        # rubocop:enable Metrics/PerceivedComplexity

        def dependency_spec
          return @custom_specification if @custom_specification

          spec = dependency.name

          if git_dependency?
            spec += ":#{git_dependency_version}" if git_dependency_version
          elsif dependency.version
            spec += ":#{dependency.version}"
          end

          spec
        end

        # Shell out to Cargo, which handles everything for us, and does
        # so without doing an install (so it's fast).
        def run_shards_outdated_command
          run_shards_command(
            "shards outdated"
          )
        end

        def run_shards_command(command)
          start = Time.now
          command = SharedHelpers.escape_command(command)
          # Helpers.setup_credentials_in_environment(credentials)

          stdout, process = Open3.capture2e({}, command)
          time_taken = Time.now - start

          # Raise an error with the output from the shell session if Cargo
          # returns a non-zero status
          return if process.success?

          raise SharedHelpers::HelperSubprocessFailed.new(
            message: stdout,
            error_context: {
              command: command,
              time_taken: time_taken,
              process_exit_value: process.to_s
            }
          )
        end

        def write_temporary_dependency_files
          write_manifest_files

          File.write(lockfile.name, lockfile.content) if lockfile
        end

        def write_manifest_files
          dependency_files.each do |file|
            path = file.name
            dir = Pathname.new(path).dirname
            FileUtils.mkdir_p(dir)
            File.write(file.name, sanitized_manifest_content(file.content))
          end
        end

        def git_dependency_version
          return unless lockfile

          TomlRB.parse(lockfile.content)
                .fetch("package", [])
                .select { |p| p["name"] == dependency.name }
                .find { |p| p["source"].end_with?(dependency.version) }
                .fetch("version")
        end

        def git_source_url
          dependency.requirements
                    .find { |r| r.dig(:source, :type) == "git" }
                    &.dig(:source, :url)
        end

        def sanitized_manifest_content(content)
          object = YAML.safe_load(content)

          # Only required fields are `name` and `version`
          YAML.dump({
            "name" => "dependabot",
            "version" => "0.1.0",
            "dependencies" => object["dependencies"] || {},
            "development_dependencies" => object["development_dependencies"] || {},
          })
        end

        def lockfile
          @lockfile ||= dependency_files
                        .find { |f| f.name == "shard.lock" }
        end

        def git_dependency?
          GitCommitChecker.new(
            dependency: dependency,
            credentials: credentials
          ).git_dependency?
        end

        def version_class
          dependency.version_class
        end
      end
    end
  end
end
