# typed: true
# frozen_string_literal: true

require "sorbet-runtime"

require "dependabot/requirement"
require "dependabot/utils"

module Dependabot
  module Shards
    # The Requirement type is responsible for "translating" Shards version constraints into a format that can be represented by Gem.
    class Requirement < Dependabot::Requirement
      extend T::Sig

      AND_SEPARATOR = ','.freeze

      # For consistency with other languages, we define a requirements array.
      # Shards doesn't have an `OR` separator for requirements, so it always contains a single element.
      sig { override.params(requirement_string: T.nilable(String)).returns(T::Array[Requirement]) }
      def self.requirements_array(requirement_string)
        [new(requirement_string)]
      end

      # Patches Gem::Requirement to make it accept requirement strings like
      # "~> 4.2.5, >= 4.2.5" without first needing to split them.
      #
      # Shards and Gem support the same version constraints except `*`,
      # so explicitly handle that, passing thru everything else.
      def initialize(*requirements)
        requirements =
          requirements.flatten
                      .flat_map { |req_string| req_string.split(AND_SEPARATOR) }
                      .map do |req|
                        case req
                        when "*" then ">= 0"
                        else
                          req
                        end
                      end

        super(requirements)
      end
    end
  end
end

Dependabot::Utils.register_requirement_class("shards", Dependabot::Shards::Requirement)
