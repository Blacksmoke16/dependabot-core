# typed: true
# frozen_string_literal: true

require "sorbet-runtime"

require "dependabot/dependency"
require "dependabot/file_parsers"
require "dependabot/file_parsers/base"
require "dependabot/git_commit_checker"
require "dependabot/shared_helpers"
require "dependabot/errors"
require "dependabot/shards/package_manager"

module Dependabot
  module Shards
    class FileParser < Dependabot::FileParsers::Base
      require "dependabot/file_parsers/base/dependency_set"

      DEPENDENCY_TYPES = %w(dependencies development_dependencies).freeze

      sig { override.returns(T::Array[Dependabot::Dependency]) }
      def parse
        dependency_set = T.let(DependencySet.new, DependencySet)

        manifest_dependencies dependency_set
        lockfile_dependencies dependency_set

        dependency_set.dependencies
      end

      sig { returns(Ecosystem) }
      def ecosystem
        @ecosystem ||= T.let(begin
          Ecosystem.new(
            name: ECOSYSTEM,
            package_manager: package_manager
          )
        end, T.nilable(Dependabot::Ecosystem))
      end

      private

      sig { override.void }
      def check_required_files
        raise "No #{PackageManager::MANIFEST_FILENAME}!" unless get_original_file(PackageManager::MANIFEST_FILENAME)
      end

      sig { params(dependency_set: Dependabot::FileParsers::Base::DependencySet).void }
      def manifest_dependencies(dependency_set)
        DEPENDENCY_TYPES.each do |type|
          next unless parsed_shard_yaml[type].is_a?(Hash)

          parsed_shard_yaml[type].each do |name, attributes|
            if lockfile
              version = dependency_version(name: name)

              # Ignore dependency versions which don't appear in the lock file or are non-numeric since they can't be compared later in the process.
              next unless version&.match?(/^\d/)
            end

            dependency_set << build_manifest_dependency(name, attributes, type)
          end
        end
      end

      sig { params(name: String, attributes: T::Hash[Symbol, String], type: String).returns(Dependabot::Dependency) }
      def build_manifest_dependency(name, attributes, type)
        Dependency.new(
          name: name,
          version: dependency_version(name: name),
          package_manager: "shards",
          requirements: [{
            requirement: attributes["version"],
            file: PackageManager::MANIFEST_FILENAME,
            source: dependency_source(name: name, attributes: attributes),
            groups: [type]
          }],
        )
      end

      sig { params(dependency_set: Dependabot::FileParsers::Base::DependencySet).void }
      def lockfile_dependencies(dependency_set)
        return unless lockfile

        parsed_lockfile["shards"].each do |name, attributes|
          dependency_set << build_lockfile_dependency(name, attributes["version"])
        end
      end

      sig { params(name: String, version: String).returns(Dependabot::Dependency) }
      def build_lockfile_dependency(name, version)
        Dependency.new(
          name: name,
          version: version,
          requirements: [],
          package_manager: "shards",
          subdependency_metadata: [] # TODO: Do we have a way to even know this?
        )
      end

      sig { returns(T::Hash[String, T.untyped]) }
      def parsed_shard_yaml
        @parsed_shard_yaml ||= YAML.safe_load(shard_yml.content)
      rescue Psych::SyntaxError
        raise Dependabot::DependencyFileNotParseable, shard_yml.path
      end

      sig { returns(T.nilable(Dependabot::DependencyFile)) }
      def shard_yml
        @shard_yml ||= T.let(
          get_original_file(PackageManager::MANIFEST_FILENAME),
          T.nilable(Dependabot::DependencyFile)
        )
      end

      sig { returns(T.nilable(T::Hash[String, T.untyped])) }
      def parsed_lockfile
        return unless lockfile

        @parsed_lockfile ||= YAML.safe_load(lockfile.content)
      rescue Psych::SyntaxError
        raise Dependabot::DependencyFileNotParseable, lockfile.path
      end

      sig { returns(T.nilable(Dependabot::DependencyFile)) }
      def lockfile
        @lockfile ||= T.let(
          get_original_file(PackageManager::LOCKFILE_FILENAME),
          T.nilable(Dependabot::DependencyFile)
        )
      end

      sig { params(name: String).returns(T.nilable(String)) }
      def dependency_version(name:)
        return unless lockfile

        shard = lockfile_details(name: name)
        return unless shard

        shard.fetch("version")
      end

      sig { params(name: String, attributes: T::Hash[String, T.untyped]).returns(T.nilable(T::Hash[Symbol, T.nilable(String)])) }
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

      sig { params(name: String).returns(T.nilable(T::Hash[String, T.untyped])) }
      def lockfile_details(name:)
        parsed_lockfile.dig("shards", name)
      end

      sig { returns(Ecosystem::VersionManager) }
      def package_manager
        @package_manager ||= T.let(
          PackageManager.new(T.must(shards_version)),
          T.nilable(Dependabot::Shards::PackageManager)
        )
      end

      sig { returns(T.nilable(String)) }
      def shards_version
        @shards_version ||= T.let(
          begin
            version = SharedHelpers.run_shell_command("shards --version")
            version.match(Dependabot::Ecosystem::VersionManager::DEFAULT_VERSION_PATTERN)&.captures&.first
          end,
          T.nilable(String)
        )
      end
    end
  end
end

Dependabot::FileParsers.register("shards", Dependabot::Shards::FileParser)
