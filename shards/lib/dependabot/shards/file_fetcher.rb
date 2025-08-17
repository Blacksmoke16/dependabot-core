# typed: strict
# frozen_string_literal: true

require "sorbet-runtime"

require "dependabot/file_fetchers"
require "dependabot/file_fetchers/base"

module Dependabot
  module Shards
    class FileFetcher < Dependabot::FileFetchers::Base
      extend T::Sig
      extend T::Helpers

      require_relative "package_manager"

      sig { override.params(filenames: T::Array[String]).returns(T::Boolean) }
      def self.required_files_in?(filenames)
        filenames.include?(PackageManager::MANIFEST_FILENAME)
      end

      sig { override.returns(String) }
      def self.required_files_message
        "Repo must contain a #{PackageManager::MANIFEST_FILENAME}."
      end

      sig { override.returns(T::Hash[Symbol, T.untyped]) }
      def ecosystem_versions
        {
          package_managers: {
            PackageManager::NAME => Utils.shards_version
          }
        }
      end

      sig { override.returns(T::Array[DependencyFile]) }
      def fetch_files
        return [] unless allow_beta_ecosystems?

        fetched_files = []
        fetched_files << shard_yml
        fetched_files << lockfile if lockfile
        # TODO: Handle path dependencies
        fetched_files
      end

      private

      sig { returns(DependencyFile) }
      def shard_yml
        @shard_yml ||= fetch_file_from_host(PackageManager::MANIFEST_FILENAME)
      end

      sig { returns(T.nilable(DependencyFile)) }
      def lockfile
        return @lockfile if defined?(@lockfile)

        @lockfile = T.let(fetch_file_if_present(PackageManager::LOCKFILE_FILENAME),
                          T.nilable(Dependabot::DependencyFile))
      end

      sig { returns(T.nilable(T::Hash[String, T.untyped])) }
      def parsed_lockfile
        return unless lockfile

        @parsed_lockfile ||= YAML.safe_load(T.must(T.must(lockfile).content))
      rescue Psych::SyntaxError
        raise Dependabot::DependencyFileNotParseable, T.must(lockfile).path
      end
    end
  end
end

Dependabot::FileFetchers.register("shards", Dependabot::Shards::FileFetcher)
