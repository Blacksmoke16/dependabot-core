# typed: true
# frozen_string_literal: true

require "dependabot/shared_helpers"
require "dependabot/errors"
require "dependabot/shards/file_updater"

module Dependabot
  module Shards
    class FileUpdater
      class LockfileUpdater
        extend T::Sig
        extend T::Helpers

        require_relative "../utils"

        def initialize(dependencies:, dependency_files:, credentials:)
          @dependencies = dependencies
          @dependency_files = dependency_files
          @credentials = credentials
        end

        sig { returns(String) }
        def updated_lockfile_content
          @updated_lockfile_content ||= generate_updated_lockfile_content
        end

        private

        sig { returns(String) }
        def generate_updated_lockfile_content
          SharedHelpers.in_a_temporary_directory(@dependency_files.first.directory) do
            SharedHelpers.with_git_configured(credentials: @credentials) do
              Utils.write_manifest_files @dependency_files

              Utils.run_shards_command "lock --update #{dependency.name}"
              updated_content = File.read(PackageManager::LOCKFILE_FILENAME)

              raise "Expected content to change!" if lockfile.content == updated_content

              updated_content
            end
          end
        end

        def dependency
          # For now, we'll only ever be updating a single dependency for Shards
          @dependencies.first
        end

        def lockfile
          @lockfile ||=
            @dependency_files.find { |f| f.name == PackageManager::LOCKFILE_FILENAME }
        end
      end
    end
  end
end
