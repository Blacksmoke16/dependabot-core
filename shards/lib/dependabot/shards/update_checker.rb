# typed: true
# frozen_string_literal: true

require "json"

require "dependabot/errors"
require "dependabot/requirements_update_strategy"
require "dependabot/shared_helpers"
require "dependabot/update_checkers"
require "dependabot/update_checkers/base"

module Dependabot
  module Shards
    class UpdateChecker < Dependabot::UpdateCheckers::Base
      require_relative "update_checker/version_resolver"

      def latest_version
        return nil if path_dependency?

        # If the dependency is pinned via:

        # A branch, the latest version is the latest commit on that branch
        unless dependency_source_details[:branch].nil?
          return git_commit_checker.head_commit_for_current_branch
        end

        # A tag, fetch the version of the latest tag
        if git_commit_checker.pinned_ref_looks_like_version?
          return git_commit_checker.local_tag_for_latest_version.fetch(:version)
        end

        # A commit, return as is
        if git_commit_checker.ref_looks_like_commit_sha? dependency.version
          return dependency.version
        end

        # None of the above, fallback on the version of the latest tag
        git_commit_checker.local_tag_for_latest_version.fetch(:version)
      end

      def latest_resolvable_version
        VersionResolver.new(
          credentials: credentials,
          dependency: dependency,
          dependency_files: dependency_files,
        ).latest_resolvable_version
      end

      def latest_resolvable_version_with_no_unlock
        return nil if path_dependency?

        @latest_resolvable_version_with_no_unlock ||=
          VersionResolver.new(
            credentials: credentials,
            dependency: dependency,
            dependency_files: dependency_files,
            # requirements_to_unlock: :none
          ).latest_resolvable_version
      end

      def updated_requirements
        RequirementsUpdater.new(
          requirements: dependency.requirements,
          update_strategy: requirements_update_strategy
        ).updated_requirements
      end

      def requirements_update_strategy
        # If passed in as an option (in the base class) honour that option
        return @requirements_update_strategy if @requirements_update_strategy

        # Otherwise, widen ranges for libraries and bump versions for apps
        library? ? RequirementsUpdateStrategy::BumpVersionsIfNecessary : RequirementsUpdateStrategy::BumpVersions
      end

      private

      def latest_version_resolvable_with_full_unlock?
        # Full unlock checks aren't implemented for Shards (yet)
        false
      end

      def updated_dependencies_after_full_unlock
        raise NotImplementedError
      end

      def dependency_source_details
        dependency.source_details
      end

      def git_commit_checker
        @git_commit_checker ||= Dependabot::GitCommitChecker.new(
          dependency: dependency,
          credentials: credentials,
          ignored_versions: ignored_versions,
          raise_on_ignored: raise_on_ignored
        )
      end

      def library?
        # If it has a lockfile, treat it as an application. Otherwise treat it as a library.
        dependency_files.none? { |f| f.name == "shard.lock" }
      end

      def path_dependency?
        dependency.requirements.any? { |r| r.dig(:source, :type) == "path" }
      end
    end
  end
end

Dependabot::UpdateCheckers.register("shards", Dependabot::Shards::UpdateChecker)
