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

      sig { override.params(filenames: T::Array[String]).returns(T::Boolean) }
      def self.required_files_in?(filenames)
        # https://github.com/crystal-lang/shards/issues/279
        filenames.include?("shard.yml")
      end

      sig { override.returns(String) }
      def self.required_files_message
        "Repo must contain shard.yml."
      end

      sig { override.returns(T::Hash[Symbol, T.untyped]) }
      def ecosystem_versions
        {
          package_managers: {
            "shards" => parsed_lockfile&.[]("version")&.to_s || "2.0"
          }
        }
      end

      sig { override.returns(T::Array[DependencyFile]) }
      def fetch_files
        fetched_files = []
        fetched_files << shard_yml
        fetched_files << lockfile if lockfile
        fetched_files
      end

      private

      def shard_yml
        @shards_yml ||= fetch_file_from_host("shard.yml")
      end

      def lockfile
        return @lockfile if defined?(@lockfile)

        @lockfile = fetch_file_if_present("shard.lock")
      end

      def parsed_lockfile
        return unless lockfile

        @parsed_lockfile ||= YAML.safe_load(lockfile.content)
      rescue Psych::SyntaxError
        raise Dependabot::DependencyFileNotParseable, lockfile.path
      end
    end
  end
end

Dependabot::FileFetchers
  .register("shards", Dependabot::Shards::FileFetcher)
