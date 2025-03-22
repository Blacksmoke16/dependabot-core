# typed: true
# frozen_string_literal: true

require "dependabot/update_checkers/base"
require "dependabot/shards/version"

module Dependabot
  module Shards
    class UpdateChecker < Dependabot::UpdateCheckers::Base
      class RequirementsUpdater
        def initialize(requirements:, target_version:)
          @requirements = requirements

          return unless target_version && Version.correct?(target_version)

          @target_version = Version.new(target_version)
        end

        def updated_requirements
          requirements.map do |req|
            if Requirement.new(req[:requirement]).satisfied_by?(target_version)
              req
            else
              req.merge(requirement: "~> #{target_version}")
            end
          end
        end

        private

        attr_reader :requirements
        attr_reader :target_version
      end
    end
  end
end
