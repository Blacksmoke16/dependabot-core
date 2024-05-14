# typed: true
# frozen_string_literal: true

require "dependabot/metadata_finders"
require "dependabot/metadata_finders/base"

module Dependabot
  module Shards
    class MetadataFinder < Dependabot::MetadataFinders::Base
      private

      def look_up_source
        source_url =
          dependency.requirements
                    .filter_map { |r| r.fetch(:source) }
                    .first&.fetch(:url, nil)

        Source.from_url(source_url)
      end
    end
  end
end

Dependabot::MetadataFinders
  .register("shards", Dependabot::Shards::MetadataFinder)
