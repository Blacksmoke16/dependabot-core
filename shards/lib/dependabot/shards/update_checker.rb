# typed: true
# frozen_string_literal: true

require "dependabot/errors"
require "dependabot/requirements_update_strategy"
require "dependabot/shared_helpers"
require "dependabot/update_checkers"
require "dependabot/update_checkers/base"
require "dependabot/update_checkers/version_filters"
require "dependabot/shards/file_updater/manifest_updater"

module Dependabot
  module Shards
    class UpdateChecker < Dependabot::UpdateCheckers::Base
      extend T::Sig
      extend T::Helpers

      require_relative "update_checker/requirements_updater"
      require_relative "update_checker/version_resolver"

      sig { override.returns(T.nilable(T.any(String, Gem::Version))) }
      def latest_version
        @latest_version ||= fetch_latest_version
      end

      sig { override.returns(T.nilable(T.any(String, Gem::Version))) }
      def latest_resolvable_version
        @latest_resolvable_version ||= fetch_latest_resolvable_version
      end

      def latest_resolvable_version_with_no_unlock
        raise NotImplementedError
      end

      def lowest_security_fix_version
        @lowest_security_fix_version ||= fetch_lowest_security_fix_version
      end

      def lowest_resolvable_security_fix_version
        raise "Dependency not vulnerable!" unless vulnerable?

        return @lowest_resolvable_security_fix_version if defined?(@lowest_resolvable_security_fix_version)

        @lowest_resolvable_security_fix_version = fetch_lowest_resolvable_security_fix_version
      end

      sig { override.returns(T::Array[T::Hash[Symbol, T.untyped]]) }
      def updated_requirements
        RequirementsUpdater.new(
          requirements: old_requirements,
          target_version: preferred_resolvable_version
        ).updated_requirements
      end

      private

      def old_requirements
        dependency.requirements
      end

      def fetch_latest_version
        return if path_dependency?

        # Shards is a bit unique in that it's entirely git/VCS based.
        # As such we can't rely on `git_commit_checker.pinned?` since there
        # will not be a `ref` in the happy path of using a `version` requirement.

        # Instead we must check for more specific matchers,
        # falling back on the latest

        # A branch, the latest version is the latest commit on that branch
        return git_commit_checker.head_commit_for_current_branch unless dependency_source_details[:branch].nil?

        # A tag, fetch the latest tag
        return latest_version_tag&.fetch(:version) if git_commit_checker.pinned_ref_looks_like_version?

        # A commit, return as is
        if (v = dependency.version) && git_commit_checker.ref_looks_like_commit_sha?(v)
          return v
        end

        # None of the above, fallback on the version of the latest tag
        latest_version_tag&.fetch(:version)
      end

      def fetch_latest_resolvable_version
        latest_resolvable_version = version_resolver_for(unlocked_requirements).latest_resolvable_version
        return current_version unless latest_resolvable_version

        Version.new(latest_resolvable_version)
      end

      def fetch_lowest_resolvable_security_fix_version
        lowest_resolvable_security_fix_version = version_resolver_for(
          force_lowest_security_fix_requirements
        ).latest_resolvable_version
        return unless lowest_resolvable_security_fix_version

        Version.new(lowest_resolvable_security_fix_version)
      end

      def unlocked_requirements
        old_requirements.map do |req|
          req.merge(requirement: ">= #{dependency.version}")
        end
      end

      def force_lowest_security_fix_requirements
        old_requirements.map do |req|
          req.merge(requirement: "= #{lowest_security_fix_version}")
        end
      end

      def fetch_lowest_security_fix_version
        return unless git_commit_checker.pinned_ref_looks_like_version? && latest_version_tag

        lowest_security_fix_version_tag.fetch(:version)
      end

      def lowest_security_fix_version_tag
        tags = git_commit_checker.local_tags_for_allowed_versions
        find_lowest_secure_version(tags)
      end

      def find_lowest_secure_version(tags)
        relevant_tags = Dependabot::UpdateCheckers::VersionFilters.filter_vulnerable_versions(tags, security_advisories)
        relevant_tags = filter_lower_tags(relevant_tags)

        relevant_tags.min_by { |tag| tag.fetch(:version) }
      end

      def filter_lower_tags(tags_array)
        return tags_array unless current_version

        tags_array
          .select { |tag| tag.fetch(:version) > current_version }
      end

      def latest_version_tag
        git_commit_checker.local_tag_for_latest_version
      end

      sig { override.returns(T::Boolean) }
      def latest_version_resolvable_with_full_unlock?
        # Full unlock checks aren't implemented for Shards (yet)
        false
      end

      sig { override.returns(T.noreturn) }
      def updated_dependencies_after_full_unlock
        raise NotImplementedError
      end

      sig { returns(T.nilable(T::Hash[T.any(String, Symbol), T.untyped])) }
      def dependency_source_details
        dependency.source_details
      end



      sig { returns(T::Boolean) }
      def path_dependency?
        dependency.requirements.any? { |r| r.dig(:source, :type) == "path" }
      end

      def prepare_manifest_for(new_requirements)
        DependencyFile.new(
          name: manifest.name,
          content: FileUpdater::ManifestUpdater.new(
            dependency.name,
            manifest.content,
            new_requirements: new_requirements
          ).updated_manifest_content,
          directory: manifest.directory
        )
      end

      # Dep creation

      def version_resolver_for(requirements)
        VersionResolver.new(
          dependency: dependency,
          manifest: prepare_manifest_for(requirements),
          lockfile: lockfile,
          repo_contents_path: repo_contents_path,
          credentials: credentials
        )
      end

      sig { returns(Dependabot::GitCommitChecker) }
      def git_commit_checker
        @git_commit_checker ||= Dependabot::GitCommitChecker.new(
          dependency: dependency,
          credentials: credentials,
          ignored_versions: ignored_versions,
          raise_on_ignored: raise_on_ignored
        )
      end

      def manifest
        @manifest ||= dependency_files.find { |file| file.name == PackageManager::MANIFEST_FILENAME }
      end

      def lockfile
        @lockfile ||= dependency_files.find { |file| file.name == PackageManager::LOCKFILE_FILENAME }
      end
    end
  end
end

Dependabot::UpdateCheckers.register("shards", Dependabot::Shards::UpdateChecker)
