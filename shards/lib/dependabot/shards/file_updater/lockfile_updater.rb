# typed: true
# frozen_string_literal: true

require "dependabot/shared_helpers"
require "dependabot/errors"
require "dependabot/shards/file_parser"
require "dependabot/shards/file_updater"
require "dependabot/shards/version"
require "dependabot/shards/requirement"

# rubocop:disable Metrics/ClassLength
module Dependabot
  module Shards
    class FileUpdater
      class LockfileUpdater
        def initialize(dependencies:, dependency_files:, credentials:)
          @dependencies = dependencies
          @dependency_files = dependency_files
          @credentials = credentials
        end

        def updated_lockfile_content
          @updated_lockfile_content ||= generate_updated_lockfile_content
        end

        private

        attr_reader :dependencies
        attr_reader :dependency_files
        attr_reader :credentials

        def generate_updated_lockfile_content
          base_directory = dependency_files.first.directory
          SharedHelpers.in_a_temporary_directory(base_directory) do
            write_temporary_dependency_files

            updated_content = run_shards_lock_command

            raise "Expected content to change!" if lockfile.content == updated_content

            updated_content
          end
        end

        def dependency
          # For now, we'll only ever be updating a single dependency for Shards
          dependencies.first
        end

        # Shell out to Shards, which handles everything for us,
        # and does so without actually installing anything (so it's fast).
        def run_shards_lock_command
          run_shards_command(
            "shards lock --update"
          )
        end

        def run_shards_command(command)
          start = Time.now
          command = SharedHelpers.escape_command(command)
          # Helpers.setup_credentials_in_environment(credentials)

          stdout, process = Open3.capture2e({}, command)
          time_taken = Time.now - start

          # Raise an error with the output from the shell session if Shards returns a non-zero status
          return File.read(PackageManager::LOCKFILE_FILENAME) if process.success?

          raise SharedHelpers::HelperSubprocessFailed.new(
            message: stdout,
            error_context: {
              command: command,
              time_taken: time_taken,
              process_exit_value: process.to_s
            }
          )
        end

        def fetch_version_from_new_lockfile
          lockfile_content = File.read("shard.lock")
          versions = YAML.safe_load(lockfile_content).fetch("shards")
                         .select { |(k, attributes)| k == dependency.name }
                         .map { |(_, attributes)| attributes }

          updated_version =
            if dependency.top_level?
              versions.max_by { |o| version_class.new(o.fetch("version")) }
            else
              versions.min_by { |o| version_class.new(o.fetch("version")) }
            end

          return unless updated_version

          version = updated_version.fetch("version")

          # Use the commit hash as it's the most accurate in this context
          if match = version.match(/(.*)\+git\.commit\.([\w\d]+)/)
            return match[1]
          end

          version
        end

        def library?
          parsed_composer_json["type"] == "library"
        end

        def write_manifest_files
          dependency_files.each do |file|
            path = file.name
            dir = Pathname.new(path).dirname
            FileUtils.mkdir_p(dir)
            File.write(file.name, file.content)
          end
        end

        def write_temporary_dependency_files
          write_manifest_files
          File.write(PackageManager::LOCKFILE_FILENAME, lockfile.content)
        end

        def lockfile
          @lockfile ||=
            dependency_files.find { |f| f.name == PackageManager::LOCKFILE_FILENAME }
        end
      end
    end
  end
end
# rubocop:enable Metrics/ClassLength
