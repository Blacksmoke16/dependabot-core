# typed: false
# frozen_string_literal: true

require "spec_helper"
require "dependabot/shards/update_checker/requirements_updater"
require "dependabot/shards/requirement"
require "dependabot/shards/version"

RSpec.describe Dependabot::Shards::UpdateChecker::RequirementsUpdater do
  let(:updater) do
    described_class.new(
      requirements: requirements,
      target_version: target_version
    )
  end

  describe "#updated_requirements" do
    subject(:updated_requirements) { updater.updated_requirements }

    context "with valid target version" do
      let(:target_version) { "1.2.3" }

      context "when current requirement is satisfied by target version" do
        let(:requirements) do
          [{ requirement: ">= 1.0.0", groups: [], file: "shard.yml", source: nil }]
        end

        it "keeps the existing requirement" do
          expect(updated_requirements.first[:requirement]).to eq(">= 1.0.0")
        end
      end

      context "with ~> operator" do
        let(:requirements) do
          [{ requirement: "~> 0.5.0", groups: [], file: "shard.yml", source: nil }]
        end

        it "updates to new pessimistic version constraint" do
          expect(updated_requirements.first[:requirement]).to eq("~> 1.2.3")
        end
      end

      context "with < operator" do
        let(:requirements) do
          [{ requirement: "< 1.0.0", groups: [], file: "shard.yml", source: nil }]
        end

        it "updates to new less-than constraint" do
          expect(updated_requirements.first[:requirement]).to eq("< 1.2.3")
        end
      end

      context "with <= operator" do
        let(:requirements) do
          [{ requirement: "<= 1.0.0", groups: [], file: "shard.yml", source: nil }]
        end

        it "updates to new less-than constraint (matches < first)" do
          expect(updated_requirements.first[:requirement]).to eq("< 1.2.3")
        end
      end

      context "with > operator" do
        let(:requirements) do
          [{ requirement: "> 0.5.0", groups: [], file: "shard.yml", source: nil }]
        end

        it "keeps current requirement when already satisfied" do
          expect(updated_requirements.first[:requirement]).to eq("> 0.5.0")
        end
      end

      context "with >= operator" do
        let(:requirements) do
          [{ requirement: ">= 2.0.0", groups: [], file: "shard.yml", source: nil }]
        end

        it "updates to new greater-than constraint (matches > first)" do
          expect(updated_requirements.first[:requirement]).to eq("> 1.2.3")
        end
      end

      context "with != operator" do
        let(:requirements) do
          [{ requirement: "!= 0.5.0", groups: [], file: "shard.yml", source: nil }]
        end

        it "keeps current requirement when already satisfied" do
          expect(updated_requirements.first[:requirement]).to eq("!= 0.5.0")
        end
      end

      context "with exact version requirement" do
        let(:requirements) do
          [{ requirement: "0.5.0", groups: [], file: "shard.yml", source: nil }]
        end

        it "updates to exact target version" do
          expect(updated_requirements.first[:requirement]).to eq("1.2.3")
        end
      end

      context "with multiple requirements" do
        let(:requirements) do
          [
            { requirement: "~> 0.5.0", groups: [], file: "shard.yml", source: nil },
            { requirement: ">= 0.1.0", groups: [], file: "shard.yml", source: nil }
          ]
        end

        it "updates all requirements" do
          expect(updated_requirements[0][:requirement]).to eq("~> 1.2.3")
          expect(updated_requirements[1][:requirement]).to eq(">= 0.1.0")
        end
      end

      context "preserves other requirement attributes" do
        let(:requirements) do
          [{ 
            requirement: "~> 0.5.0", 
            groups: ["development"], 
            file: "shard.yml", 
            source: { type: "git", url: "https://github.com/example/repo.git" }
          }]
        end

        it "preserves groups, file, and source" do
          updated = updated_requirements.first
          expect(updated[:groups]).to eq(["development"])
          expect(updated[:file]).to eq("shard.yml")
          expect(updated[:source]).to eq({ type: "git", url: "https://github.com/example/repo.git" })
        end
      end
    end

    context "with invalid target version" do
      context "when target_version is nil" do
        let(:target_version) { nil }
        let(:requirements) do
          [{ requirement: "~> 0.5.0", groups: [], file: "shard.yml", source: nil }]
        end

        it "raises error when target_version is nil" do
          expect { updated_requirements }.to raise_error(ArgumentError, /Need a Gem::Version/)
        end
      end

      context "when target_version is invalid" do
        let(:target_version) { "invalid-version" }
        let(:requirements) do
          [{ requirement: "~> 0.5.0", groups: [], file: "shard.yml", source: nil }]
        end

        it "raises error when target_version is invalid" do
          expect { updated_requirements }.to raise_error(ArgumentError, /Need a Gem::Version/)
        end
      end
    end
  end
end
