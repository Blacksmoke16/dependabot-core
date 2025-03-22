# typed: true
# frozen_string_literal: true

require "dependabot/errors"
require "dependabot/requirements_update_strategy"
require "dependabot/shared_helpers"
require "dependabot/update_checkers"
require "dependabot/update_checkers/base"
require "dependabot/update_checkers/version_filters"

module Dependabot
  module Shards
    class UpdateChecker < Dependabot::UpdateCheckers::Base
      extend T::Sig
      extend T::Helpers

      require_relative "update_checker/requirements_updater"
      require_relative "update_checker/version_resolver"

      sig { override.returns(T.nilable(T.any(String, Gem::Version))) }
      def latest_version
        return nil if path_dependency?

        # Shards is a bit unique in that it's entirely git/VCS based.
        # As such we can't rely on `git_commit_checker.pinned?` since there
        # will not be a `ref` in the happy path of using a `version` requirement.

        # Instead we must check for more specific matchers,
        # falling back on the latest

        # A branch, the latest version is the latest commit on that branch
        return git_commit_checker.head_commit_for_current_branch unless dependency_source_details[:branch].nil?

        # A tag, fetch the latest tag
        if git_commit_checker.pinned_ref_looks_like_version?
          return git_commit_checker.local_tag_for_latest_version&.fetch(:version)
        end

        # A commit, return as is
        if (v = dependency.version) && git_commit_checker.ref_looks_like_commit_sha?(v)
          return v
        end

        # None of the above, fallback on the version of the latest tag
        git_commit_checker.local_tag_for_latest_version&.fetch(:version)
      end

      sig { override.returns(T.nilable(T.any(String, Gem::Version))) }
      def latest_resolvable_version
        VersionResolver.new(
          credentials: credentials,
          dependency: dependency,
          dependency_files: dependency_files
        ).latest_resolvable_version
      end

      def lowest_security_fix_version
        @lowest_security_fix_version ||= fetch_lowest_security_fix_version
      end

      sig { override.returns(T.nilable(T.any(String, Dependabot::Version))) }
      def latest_resolvable_version_with_no_unlock
        return nil if path_dependency?

        @latest_resolvable_version_with_no_unlock ||=
          VersionResolver.new(
            credentials: credentials,
            dependency: dependency,
            dependency_files: dependency_files
          ).latest_resolvable_version
      end

      sig { override.returns(T::Array[T::Hash[Symbol, T.untyped]]) }
      def updated_requirements
        RequirementsUpdater.new(
          requirements: dependency.requirements,
          latest_resolvable_version: latest_resolvable_version&.to_s,
          update_strategy: requirements_update_strategy
        ).updated_requirements
      end

      sig { override.returns(T::Boolean) }
      def requirements_unlocked_or_can_be?
        !requirements_update_strategy.lockfile_only?
      end

      sig { returns(RequirementsUpdateStrategy) }
      def requirements_update_strategy
        # If passed in as an option (in the base class) honour that option
        return @requirements_update_strategy if @requirements_update_strategy

        # Otherwise, widen ranges for libraries and bump versions for apps
        library? ? RequirementsUpdateStrategy::WidenRanges : RequirementsUpdateStrategy::BumpVersionsIfNecessary
      end

      private

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

      sig { returns(Dependabot::GitCommitChecker) }
      def git_commit_checker
        @git_commit_checker ||= Dependabot::GitCommitChecker.new(
          dependency: dependency,
          credentials: credentials,
          ignored_versions: ignored_versions,
          raise_on_ignored: raise_on_ignored
        )
      end

      sig { returns(T::Boolean) }
      def library?
        # If it has a lockfile, treat it as an application. Otherwise treat it as a library.
        dependency_files.none? { |f| f.name == PackageManager::LOCKFILE_FILENAME }
      end

      sig { returns(T::Boolean) }
      def path_dependency?
        dependency.requirements.any? { |r| r.dig(:source, :type) == "path" }
      end
    end
  end
end

Dependabot::UpdateCheckers.register("shards", Dependabot::Shards::UpdateChecker)
