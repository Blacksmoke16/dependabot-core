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

      sig { override.returns(T::Array[DependencyFile]) }
      def fetch_files
        fetched_files = []
        fetched_files << shard_yml
        fetched_files << shard_lock if shard_lock
        fetched_files
      end

      private

      def shard_yml
        @shards_yml ||= fetch_file_from_host("shard.yml")
      end

      def shard_lock
        return @shard_lock if defined?(@shard_lock)

        @shard_lock = fetch_file_if_present("shard.lock")
      end
    end
  end
end

Dependabot::FileFetchers
  .register("shards", Dependabot::Shards::FileFetcher)
