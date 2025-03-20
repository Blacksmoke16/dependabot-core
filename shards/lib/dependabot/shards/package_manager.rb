# typed: strong
# frozen_string_literal: true

require "sorbet-runtime"
require "dependabot/ecosystem"
require "dependabot/shards/version"

module Dependabot
  module Shards
    ECOSYSTEM = "crystal"

    class PackageManager < Dependabot::Ecosystem::VersionManager
      extend T::Sig

      NAME = "shards"

      # https://github.com/crystal-lang/shards/issues/279
      MANIFEST_FILENAME = "shard.yml"
      LOCKFILE_FILENAME = "shard.lock"

      sig { params(raw_version: String).void }
      def initialize(raw_version)
        super(
          name: NAME,
          version: Version.new(raw_version),
        )
      end

      sig { returns(T::Boolean) }
      def deprecated?
        false
      end

      sig { returns(T::Boolean) }
      def unsupported?
        false
      end
    end
  end
end
