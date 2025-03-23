# typed: true
# frozen_string_literal: true

require "dependabot/file_updaters/base"
require "dependabot/shards/file_updater/requirement_replacer"

module Dependabot
  module Shards
    class FileUpdater < FileUpdaters::Base
      class ManifestUpdater
        require_relative "../utils"

        def initialize(dependency_name, content, new_requirements:)
          @dependency_name = dependency_name
          @content = content
          @new_requirements = new_requirements
        end

        def updated_manifest_content
          updated_content = @content

          @new_requirements.each do |new|
            updated_content = Utils.update_dep_version(updated_content, new[:groups], @dependency_name,
                                                       new[:requirement])
          end

          updated_content
        end
      end
    end
  end
end
