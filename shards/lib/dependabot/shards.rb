# typed: strong
# frozen_string_literal: true

# These all need to be required so the various classes can be registered in a
# lookup table of package manager names to concrete classes.
require "dependabot/shards/file_fetcher"
require "dependabot/shards/file_parser"
require "dependabot/shards/update_checker"
# require "dependabot/shards/file_updater"
# require "dependabot/shards/metadata_finder"
require "dependabot/shards/requirement"
require "dependabot/shards/version"

require "dependabot/pull_request_creator/labeler"
Dependabot::PullRequestCreator::Labeler
  .register_label_details("shards", name: "crystal", colour: "000000")

require "dependabot/dependency"
Dependabot::Dependency
  .register_production_check("shards", ->(_) { true })
