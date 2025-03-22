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

        def initialize(dependency:, manifest:, repo_contents_path:, credentials:)
          @dependency = dependency
          @manifest = manifest
          @repo_contents_path = repo_contents_path
          @credentials = credentials
        end

        sig { returns(String) }
        def updated_lockfile_content
          @updated_lockfile_content ||= generate_updated_lockfile_content
        end

        private

        sig { returns(String) }
        def generate_updated_lockfile_content
          SharedHelpers.in_a_temporary_repo_directory(manifest.directory, repo_contents_path) do
            File.write(manifest.name, manifest.content)

            SharedHelpers.with_git_configured(credentials: credentials) do
              Utils.run_shards_command(
                "lock --update #{dependency.name}",
                fingerprint: "shards lock --update <dependency_name>"
              )

              File.read(PackageManager::LOCKFILE_FILENAME)
            end
          end
        end

        attr_reader :dependency
        attr_reader :manifest
        attr_reader :repo_contents_path
        attr_reader :credentials
      end
    end
  end
end
