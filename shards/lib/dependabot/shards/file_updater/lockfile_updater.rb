# typed: true
# frozen_string_literal: true

require "dependabot/file_updaters/base"
require "dependabot/shared_helpers"
require "dependabot/logger"

module Dependabot
  module Shards
    class FileUpdater < Dependabot::FileUpdaters::Base
      class LockfileUpdater
        extend T::Sig
        extend T::Helpers

        require_relative "../utils"

        def initialize(dependency:, manifest:, repo_contents_path:, credentials:, allow_error: true)
          @dependency = dependency
          @manifest = manifest
          @repo_contents_path = repo_contents_path
          @credentials = credentials
          @allow_error = allow_error
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
              try_lockfile_update dependency.name

              File.read(PackageManager::LOCKFILE_FILENAME)
            end
          end
        end

        def try_lockfile_update(dependency_name)
          Utils.run_shards_command(
            "lock --update #{dependency_name}",
            fingerprint: "shards lock --update <dependency_name>"
          )
        rescue SharedHelpers::HelperSubprocessFailed => e
          # This class is not only used for final lockfile updates, but for
          # checking resolvability. So resolvability errors here are expected in
          # certain situations and will result in `no_update_possible` outcomes.
          # That said, since we're swallowing all errors we at least log them to ease debugging.
          Dependabot.logger.info("Lockfile failed to be updated due to error:\n#{e.message}")
          raise e unless @allow_error
        end

        attr_reader :dependency
        attr_reader :manifest
        attr_reader :repo_contents_path
        attr_reader :credentials
      end
    end
  end
end
