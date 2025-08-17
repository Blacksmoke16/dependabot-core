# typed: false
# frozen_string_literal: true

require "spec_helper"
require "dependabot/shards"
require_common_spec "shared_examples_for_autoloading"

RSpec.describe Dependabot::Shards do
  it_behaves_like "it registers the required classes", "shards"
end
