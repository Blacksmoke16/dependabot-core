# typed: true
# frozen_string_literal: true

require "dependabot/dependency"
require "dependabot/composer/version"
require "dependabot/file_parsers"
require "dependabot/file_parsers/base"
require "dependabot/shared_helpers"
require "dependabot/errors"

module Dependabot
  module Shards
    class FileParser < Dependabot::FileParsers::Base
      require "dependabot/file_parsers/base/dependency_set"

      DEPENDENCY_TYPES = %w(dependencies development_dependencies).freeze

      def parse
        dependency_set = DependencySet.new
        dependency_set += manifest_dependencies
        dependency_set += lockfile_dependencies
        dependency_set.dependencies
      end

      private

      def check_required_files
        raise "No shard.yml!" unless get_original_file("shard.yml")
      end

      def build_manifest_dependency(name, attributes, type)
        Dependency.new(
          name: name,
          version: dependency_version(name: name),
          package_manager: "shards",
          requirements: [{
            requirement: attributes["version"],
            file: "shard.yml",
            source: dependency_source(name: name, attributes: attributes),
            groups: [type]
          }],
        )
      end

      def manifest_dependencies
        dependencies = DependencySet.new

        DEPENDENCY_TYPES.each do |type|
          next unless parsed_shard_yaml[type].is_a?(Hash)

          parsed_shard_yaml[type].each do |name, attributes|
            if lockfile
              version = dependency_version(name: name)

              # Ignore dependency versions which don't appear in the lock file or are non-numeric since they can't be compared later in the process.
              next unless version&.match?(/^\d/)
            end

            dependencies << build_manifest_dependency(name, attributes, type)
          end
        end

        dependencies
      end

      def parsed_lockfile
        return unless lockfile

        @parsed_lockfile ||= YAML.safe_load(lockfile.content)
      rescue Psych::SyntaxError
        raise Dependabot::DependencyFileNotParseable, lockfile.path
      end

      def parsed_shard_yaml
        @parsed_shard_yaml ||= YAML.safe_load(shard_yml.content)
      rescue Psych::SyntaxError
        raise Dependabot::DependencyFileNotParseable, shard_yml.path
      end

      def shard_yml
        @shard_yml ||= get_original_file("shard.yml")
      end

      def lockfile
        @lockfile ||= get_original_file("shard.lock")
      end

      def dependency_version(name:)
        return unless lockfile

        shard = lockfile_details(name: name)
        return unless shard

        shard.fetch("version")
      end

      def dependency_source(name:, attributes:)
        if attributes.has_key?("path")
          return { type: "path" }
        end

        # https://github.com/crystal-lang/shards/blob/950f383050a138a9d0e74ec48af91caceff13bfe/src/resolvers/git.cr#L121-L122
        url = if source = attributes["github"]
          "https://github.com/#{source}.git"
        elsif source = attributes["gitlab"]
          "https://gitlab.com/#{source}.git"
        elsif source = attributes["bitbucket"]
          "https://bitbucket.com/#{source}.git"
        elsif url = attributes["git"]
          url
        end

        # TODO: Support Mercurial and Fossil?
        return unless url

        {
          type: "git",
          url: url,
          branch: attributes["branch"],
          ref: attributes["tag"] || attributes["commit"]
        }
      end

      def lockfile_details(name:)
        parsed_lockfile.dig("shards", name)
      end

      # rubocop:disable Metrics/PerceivedComplexity
      def lockfile_dependencies
        dependencies = DependencySet.new

        return dependencies unless lockfile

        parsed_lockfile["shards"].each do |name, attributes|
          dependencies << build_lockfile_dependency(name, attributes["version"])
        end

        dependencies
      end

      # rubocop:enable Metrics/PerceivedComplexity
      def build_lockfile_dependency(name, version)
        Dependency.new(
          name: name,
          version: version,
          requirements: [],
          package_manager: "shards",
          subdependency_metadata: [] # TODO: Do we have a way to even know this?
        )
      end
    end
  end
end

Dependabot::FileParsers.register("shards", Dependabot::Shards::FileParser)
