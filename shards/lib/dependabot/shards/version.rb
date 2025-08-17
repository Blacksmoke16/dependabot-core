# typed: true
# frozen_string_literal: true

require "dependabot/version"
require "dependabot/utils"

# Shards versions can include build information, which Ruby can't parse.
# This class augments Gem::Version with build information.
# However, shards does not take build version into account when comparing versions.

module Dependabot
  module Shards
    class Version < Dependabot::Version
      attr_reader :build_info

      VERSION_PATTERN = Gem::Version::VERSION_PATTERN + '(\+[0-9a-zA-Z\-.]+)?'
      ANCHORED_VERSION_PATTERN = /\A\s*(#{VERSION_PATTERN})?\s*\z/

      def self.correct?(version)
        return false if version.nil?

        version.to_s.match?(ANCHORED_VERSION_PATTERN)
      end

      def initialize(version)
        @version_string = version.to_s

        version, @build_info = version.to_s.split("+") if version.to_s.include?("+")

        super
      end

      def to_s
        @version_string
      end

      def inspect # :nodoc:
        "#<#{self.class} #{@version_string}>"
      end
    end
  end
end

Dependabot::Utils.register_version_class("shards", Dependabot::Shards::Version)
