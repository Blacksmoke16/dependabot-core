# typed: true
# frozen_string_literal: true

require "sorbet-runtime"

require "dependabot/requirement"
require "dependabot/utils"

module Dependabot
  module Shards
    class Requirement < Dependabot::Requirement
      extend T::Sig

      OR_SEPARATOR = ','.freeze

      def self.parse(obj)
        new_obj = obj.gsub(/@\w+/, "").gsub(/[a-z0-9\-_\.]*\sas\s+/i, "")
        return DefaultRequirement if new_obj == ""

        super(new_obj)
      end

      # Returns an array of requirements. At least one requirement from the
      # returned array must be satisfied for a version to be valid.
      sig { override.params(requirement_string: T.nilable(String)).returns(T::Array[Requirement]) }
      def self.requirements_array(requirement_string)
        T.must(requirement_string).strip.split(OR_SEPARATOR).map do |req_string|
          new(req_string)
        end
      end

      private

      def convert_wildcard_req(req_string)
        if req_string.start_with?(">", "<")
          msg = "Illformed requirement [#{req_string.inspect}]"
          raise Gem::Requirement::BadRequirementError, msg
        end

        version = req_string.gsub(/^~/, "").gsub(/(?:\.|^)[\*x]/, "")
        "~> #{version}.0"
      end

      def convert_tilde_req(req_string)
        version = req_string.gsub(/^~/, "")
        "~> #{version}"
      end
    end
  end
end

Dependabot::Utils.register_requirement_class("shards", Dependabot::Shards::Requirement)
