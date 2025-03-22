# typed: strict
# frozen_string_literal: true

require "dependabot/file_updaters"
require "dependabot/file_updaters/base"
require "dependabot/shards/file_updater/lockfile_updater"
require "dependabot/shards/file_updater/manifest_updater"

module Dependabot
  module Shards
    class FileUpdater < Dependabot::FileUpdaters::Base
      sig { override.returns(T::Array[Regexp]) }
      def self.updated_files_regex
        [
          /^shard\.yml$/,
          /^shard\.lock$/
        ]
      end

      sig { override.returns(T::Array[Dependabot::DependencyFile]) }
      def updated_dependency_files
        updated_files = []

        SharedHelpers.in_a_temporary_repo_directory(manifest.directory, repo_contents_path) do
          updated_manifest = nil

          if file_changed?(manifest)
            updated_manifest = updated_file(file: manifest, content: updated_manifest_content)
            updated_files << updated_manifest
          end

          updated_files << updated_file(file: lockfile, content: updated_lockfile_content(updated_manifest)) if lockfile
        end

        updated_files
      end

      private

      def dependency
        # For now we will be updating a single dependency.
        # TODO: Revisit when/if implementing full unlocks
        dependencies.first
      end

      sig { override.void }
      def check_required_files
        raise "No #{PackageManager::MANIFEST_FILENAME}!" unless manifest
      end

      sig { returns(String) }
      def updated_manifest_content
        ManifestUpdater.new(
          dependency.name,
          manifest.content,
          new_requirements: dependency.requirements
        ).updated_manifest_content
      end

      sig { params(updated_manifest: T.nilable(Dependabot::DependencyFile)).returns(String) }
      def updated_lockfile_content(updated_manifest)
        LockfileUpdater.new(
          dependency: dependency,
          manifest: updated_manifest || manifest,
          repo_contents_path: repo_contents_path,
          credentials: credentials
        ).updated_lockfile_content
      end

      sig { returns(T.nilable(Dependabot::DependencyFile)) }
      def manifest
        @manifest ||= get_original_file(PackageManager::MANIFEST_FILENAME)
      end

      sig { returns(T.nilable(Dependabot::DependencyFile)) }
      def lockfile
        @lockfile ||= get_original_file(PackageManager::LOCKFILE_FILENAME)
      end
    end
  end
end

Dependabot::FileUpdaters.register("shards", Dependabot::Shards::FileUpdater)
