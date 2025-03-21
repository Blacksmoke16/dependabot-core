# typed: true
# frozen_string_literal: true

require "sorbet-runtime"

require "dependabot/shards/requirement"
require "dependabot/shards/update_checker"
require "dependabot/shards/version"
require "dependabot/requirements_update_strategy"

module Dependabot
  module Shards
    class UpdateChecker
      class RequirementsUpdater
        extend T::Sig

        ALLOWED_UPDATE_STRATEGIES = T.let(
          [
            RequirementsUpdateStrategy::LockfileOnly,
            RequirementsUpdateStrategy::WidenRanges,
            RequirementsUpdateStrategy::BumpVersions,
            RequirementsUpdateStrategy::BumpVersionsIfNecessary
          ].freeze,
          T::Array[Dependabot::RequirementsUpdateStrategy]
        )

        def initialize(requirements:, update_strategy:,
                       latest_resolvable_version:)
          @requirements = requirements
          @update_strategy = update_strategy

          check_update_strategy

          return unless latest_resolvable_version

          @latest_resolvable_version =
            version_class.new(latest_resolvable_version)
        end

        def updated_requirements
          # return requirements if update_strategy.lockfile_only?
          # return requirements unless latest_resolvable_version

          requirements.map { |req| updated_requirement(req) }
        end

        private

        attr_reader :requirements
        attr_reader :update_strategy
        attr_reader :latest_resolvable_version

        def check_update_strategy
          return if ALLOWED_UPDATE_STRATEGIES.include?(update_strategy)

          raise "Unknown update strategy: #{update_strategy}"
        end

        # rubocop:disable Metrics/PerceivedComplexity
        def updated_requirement(req)
          req_string = req[:requirement].strip

          return req unless req_string.match?(/\d/)
          return req if req_satisfied_by_latest_resolvable?(req_string) &&
                        update_strategy != RequirementsUpdateStrategy::BumpVersions

          new_req =
            case update_strategy
            when RequirementsUpdateStrategy::WidenRanges
              widen_requirement(req)
            when RequirementsUpdateStrategy::BumpVersions, RequirementsUpdateStrategy::BumpVersionsIfNecessary
              update_requirement_version(req)
            end

          new_req.merge(requirement: new_req[:requirement])
        end

        def update_requirement_version(req)
          current_requirement = req[:requirement]
          reqs = current_requirement.strip

          updated_requirement =
            if reqs.count > 1
              "^#{latest_resolvable_version}"
            elsif reqs.any? { |r| r.match?(/<|(\s+-\s+)/) }
              update_range_requirement(current_requirement)
            elsif reqs.any? { |r| r.match?(/>[^=]/) }
              current_requirement
            else
              update_version_string(current_requirement)
            end

          req.merge(requirement: updated_requirement)
        end

        def req_satisfied_by_latest_resolvable?(requirement_string)
          ruby_requirements(requirement_string)
            .any? { |r| r.satisfied_by?(latest_resolvable_version) }
        end

        def ruby_requirements(requirement_string)
          Shards::Requirement.requirements_array(requirement_string)
        end

        def version_class
          Shards::Version
        end
      end
    end
  end
end
