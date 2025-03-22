# typed: strong
# frozen_string_literal: true

require "sorbet-runtime"
require "dependabot/ecosystem"
require "dependabot/shards/requirement"
require "dependabot/shards/version"

module Dependabot
  module Shards
    class Language < Dependabot::Ecosystem::VersionManager
      extend T::Sig

      NAME = "crystal"

      sig { params(raw_version: String, requirement: T.nilable(Requirement)).void }
      def initialize(raw_version, requirement: nil)
        super(
          name: NAME,
          version: Version.new(raw_version),
          requirement: requirement
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
