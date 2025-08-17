# typed: true
# frozen_string_literal: true

require "dependabot/update_checkers/base"
require "dependabot/shards/version"

module Dependabot
  module Shards
    class UpdateChecker < Dependabot::UpdateCheckers::Base
      class RequirementsUpdater
        OPERATORS = %w(< <= > >= !=).freeze

        def initialize(requirements:, target_version:)
          @requirements = requirements

          return unless target_version && Version.correct?(target_version)

          @target_version = Version.new(target_version)
        end

        def updated_requirements
          requirements.map do |req|
            current_requirement_string = req[:requirement]
            current_requirement = Requirement.new current_requirement_string

            # TODO: Is there a more robust way to handle this?
            new_requirement = if current_requirement.satisfied_by?(target_version)
                                current_requirement_string
                              elsif current_requirement_string.start_with?("~>")
                                "~> #{target_version}"
                              elsif (operator_index = OPERATORS.find_index { |o|
                                current_requirement_string.start_with?(o)
                              })
                                "#{OPERATORS[operator_index]} #{target_version}"
                              else
                                target_version
                              end

            req.merge(requirement: new_requirement)
          end
        end

        private

        attr_reader :requirements
        attr_reader :target_version
      end
    end
  end
end
