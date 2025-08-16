# typed: true
# frozen_string_literal: true

require "dependabot/update_checkers/base"
require "dependabot/shards/file_updater/lockfile_updater"

module Dependabot
  module Shards
    class UpdateChecker < Dependabot::UpdateCheckers::Base
      class VersionResolver
        def initialize(dependency:, manifest:, lockfile:, repo_contents_path:, credentials:)
          @dependency         = dependency
          @manifest           = manifest
          @lockfile           = lockfile
          @credentials        = credentials
          @repo_contents_path = repo_contents_path
        end

        def latest_resolvable_version
          @latest_resolvable_version ||= fetch_latest_resolvable_version
        end

        private

        def fetch_latest_resolvable_version
          updated_lockfile_content = FileUpdater::LockfileUpdater.new(
            dependency: dependency,
            manifest: manifest,
            repo_contents_path: repo_contents_path,
            credentials: credentials,
            allow_error: false
          ).updated_lockfile_content

          return if lockfile && updated_lockfile_content == lockfile.content

          updated_lockfile = DependencyFile.new(
            name: PackageManager::MANIFEST_FILENAME,
            content: updated_lockfile_content,
            directory: manifest.directory
          )

          YAML.safe_load(updated_lockfile.content)&.dig("shards", dependency.name, "version")
        end

        attr_reader :dependency
        attr_reader :manifest
        attr_reader :lockfile
        attr_reader :repo_contents_path
        attr_reader :credentials
      end
    end
  end
end
