# typed: true
# frozen_string_literal: true

require "dependabot/version"
require "dependabot/utils"

module Dependabot
  module Shards
    class Version < Dependabot::Version
    end
  end
end

Dependabot::Utils.register_version_class("shards", Dependabot::Shards::Version)
