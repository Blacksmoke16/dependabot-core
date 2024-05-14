# typed: false
# frozen_string_literal: true

require "octokit"
require "spec_helper"
require "dependabot/dependency"
require "dependabot/shards/metadata_finder"
require_common_spec "metadata_finders/shared_examples_for_metadata_finders"

RSpec.describe Dependabot::Shards::MetadataFinder do
  subject(:finder) do
    described_class.new(dependency: dependency, credentials: credentials)
  end

  let(:dependency_name) { "crystal-db" }
  let(:credentials) do
    [{
      "type" => "git_source",
      "host" => "github.com",
      "username" => "x-access-token",
      "password" => "token"
    }]
  end
  let(:dependency) do
    Dependabot::Dependency.new(
      name: dependency_name,
      version: "0.13.1",
      requirements: requirements,
      package_manager: "shards"
    )
  end

  it_behaves_like "a dependency metadata finder"

  describe "#source_url" do
    subject(:source_url) { finder.source_url }

    context "when there is a source URL on the dependency" do
      let(:requirements) do
        [{
          file: "shard.yml",
          requirement: "~> 0.13.0",
          groups: [],
          source: {
            type: "git",
            url: "https://github.com/crystal-lang/crystal-db"
          }
        }]
      end

      it { is_expected.to eq("https://github.com/crystal-lang/crystal-db") }
    end
  end
end
