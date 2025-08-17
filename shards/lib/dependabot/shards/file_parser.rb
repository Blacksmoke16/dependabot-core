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
require "dependabot/shards/requirement"
require "dependabot/shards/language"
require "dependabot/ecosystem"

module Dependabot
  module Shards
    class FileParser < Dependabot::FileParsers::Base
      require "dependabot/file_parsers/base/dependency_set"
      require_relative "utils"

      DEPENDENCY_GROUP_KEYS = T.let([
        {
          manifest: "dependencies",
          group: "runtime"
        },
        {
          manifest: "development_dependencies",
          group: "development"
        }
      ].freeze, T::Array[T::Hash[Symbol, String]])

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
            package_manager: package_manager,
            language: language
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
        DEPENDENCY_GROUP_KEYS.each do |keys|
          manifest = keys[:manifest]
          next unless manifest.is_a?(String)
          next unless parsed_shard_yaml[manifest].is_a?(Hash)

          parsed_shard_yaml[manifest].each do |name, attributes|
            if lockfile
              version = dependency_version(name: name)

              # Ignore dependency versions which don't appear in the lock file or are non-numeric
              # since they can't be compared later in the process.
              next unless version&.match?(/^\d/)
            end

            dependency_set << build_manifest_dependency(name, attributes, keys)
          end
        end
      end

      sig do
        params(
          name: String,
          attributes: T::Hash[Symbol, String],
          keys: T::Hash[Symbol, String]
        ).returns(Dependabot::Dependency)
      end
      def build_manifest_dependency(name, attributes, keys)
        group = T.must(keys[:group])

        # If a shard does not specify a tag, version, commit, path, or branch
        # the default behavior is to treat it as unbound
        requirement = if %w(tag version commit path branch).none? { |k| attributes.key?(k) }
                        Dependabot::Shards::Requirement.new("*").to_s
                      else
                        attributes["version"]
                      end

        Dependency.new(
          name: name,
          version: dependency_version(name: name),
          package_manager: PackageManager::NAME,
          requirements: [{
            requirement: requirement,
            file: PackageManager::MANIFEST_FILENAME,
            source: dependency_source(name: name, attributes: attributes),
            groups: [group]
          }]
        )
      end

      sig { params(dependency_set: Dependabot::FileParsers::Base::DependencySet).void }
      def lockfile_dependencies(dependency_set)
        return unless lockfile

        parsed_lockfile["shards"].each do |name, _|
          version = dependency_version(name: name)
          next unless version.is_a?(String)

          dependency_set << build_lockfile_dependency(name, version)
        end
      end

      sig { params(name: String, version: String).returns(Dependabot::Dependency) }
      def build_lockfile_dependency(name, version)
        # Determine if this transitive dependency is production or development
        production = production_dependency?(name)

        Dependency.new(
          name: name,
          version: version,
          requirements: [],
          package_manager: PackageManager::NAME,
          subdependency_metadata: [{
            production: production
          }]
        )
      end

      sig { returns(T::Hash[String, T.untyped]) }
      def parsed_shard_yaml
        @parsed_shard_yaml ||= YAML.safe_load(shard_yml&.content || "")
      rescue Psych::SyntaxError
        raise Dependabot::DependencyFileNotParseable, shard_yml&.path || "unknown"
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

        @parsed_lockfile ||= YAML.safe_load(lockfile&.content || "")
      rescue Psych::SyntaxError
        raise Dependabot::DependencyFileNotParseable, lockfile&.path || "unknown"
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

        version = shard["version"]
        return unless version.is_a?(String)

        if version.include?("+git.commit")
          version.split("+git.commit.")[1]
        else
          version
        end
      end

      sig do
        params(name: String,
               attributes: T::Hash[String,
                                   T.untyped])
          .returns(T.nilable(T::Hash[Symbol, T.nilable(String)]))
      end
      def dependency_source(name:, attributes:)
        return { type: "path" } if attributes.key?("path")

        # https://github.com/crystal-lang/shards/blob/950f383050a138a9d0e74ec48af91caceff13bfe/src/resolvers/git.cr#L121-L122
        url = if (source = attributes["github"])
                "https://github.com/#{source}.git"
              elsif (source = attributes["gitlab"])
                "https://gitlab.com/#{source}.git"
              elsif (source = attributes["bitbucket"])
                "https://bitbucket.com/#{source}.git"
              elsif (url = attributes["git"])
                url
              end

        # TODO: Support Mercurial and Fossil?
        return unless url

        ref = if (branch = attributes["branch"])
                branch
              elsif (v = dependency_version(name: name))
                "v#{v}"
              end

        {
          type: "git",
          url: url,
          branch: attributes["branch"],
          ref: attributes["tag"] || attributes["commit"] || ref
        }
      end

      sig { params(name: String).returns(T.nilable(T::Hash[String, T.untyped])) }
      def lockfile_details(name:)
        parsed_lockfile&.dig("shards", name)
      end

      sig { params(name: String).returns(T::Boolean) }
      def production_dependency?(name)
        # Check if this dependency is listed in the runtime dependencies section
        runtime_deps = parsed_shard_yaml.dig("dependencies")&.keys || []

        # If it's directly listed as a runtime dependency, it's production
        return true if runtime_deps.include?(name)

        # If it's directly listed as a development dependency, it's not production
        dev_deps = parsed_shard_yaml.dig("development_dependencies")&.keys || []
        return false if dev_deps.include?(name)

        # For transitive dependencies, check if any of their parent dependencies are production
        # This is a simplified approach - a more sophisticated version would recursively
        # trace the dependency tree, but for now we'll default to production
        true
      end

      sig { returns(Ecosystem::VersionManager) }
      def package_manager
        @package_manager ||= T.let(
          PackageManager.new(T.must(Utils.shards_version)),
          T.nilable(Dependabot::Shards::PackageManager)
        )
      end

      sig { returns(T.nilable(Ecosystem::VersionManager)) }
      def language
        version = crystal_version
        return unless version

        requirement =
          if (req = parsed_shard_yaml["crystal"])
            Dependabot::Shards::Requirement.new req
          end

        Language.new(
          version,
          requirement: requirement
        )
      end

      sig { returns(T.nilable(String)) }
      def crystal_version
        @crystal_version ||= T.let(
          begin
            version = Utils.run_crystal_command("--version")
            version.match(Dependabot::Ecosystem::VersionManager::DEFAULT_VERSION_PATTERN)&.captures&.first
          end,
          T.nilable(String)
        )
      end
    end
  end
end

Dependabot::FileParsers.register("shards", Dependabot::Shards::FileParser)
