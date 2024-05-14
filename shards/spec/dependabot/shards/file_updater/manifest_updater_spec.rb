# typed: false
# frozen_string_literal: true

require "spec_helper"
require "dependabot/shards/file_updater/manifest_updater"
require "dependabot/shards/version"

RSpec.describe Dependabot::Shards::FileUpdater::ManifestUpdater do
  let(:updater) do
    described_class.new(
      dependency_name,
      content,
      new_requirements: new_requirements
    )
  end

  let(:dependency_name) { "db" }
  let(:content) do
    <<~CONTENT
      dependencies:
        db:
          github: crystal-lang/crystal-db
          version: ~> 0.10.0
        openssl:
          github: datanoise/openssl.cr
    CONTENT
  end

  describe "#updated_manifest_content" do
    subject(:updated_manifest_content) { updater.updated_manifest_content }

    context "with single requirement update" do
      let(:new_requirements) do
        [{ requirement: "~> 0.13.0", groups: ["runtime"], file: "shard.yml", source: nil }]
      end

      it "updates the version requirement" do
        expect(updated_manifest_content).to include("version: ~> 0.13.0")
        expect(updated_manifest_content).not_to include("version: ~> 0.10.0")
      end

      it "preserves other dependencies" do
        expect(updated_manifest_content).to include("openssl:")
        expect(updated_manifest_content).to include("github: datanoise/openssl.cr")
      end
    end

    context "with multiple requirement updates to same dependency" do
      let(:new_requirements) do
        [
          { requirement: "~> 0.13.0", groups: ["runtime"], file: "shard.yml", source: nil },
          { requirement: "~> 0.13.1", groups: ["runtime"], file: "shard.yml", source: nil }
        ]
      end

      it "applies requirement updates sequentially (last one wins)" do
        expect(updated_manifest_content).to include("version: ~> 0.13.1")
        expect(updated_manifest_content).not_to include("version: ~> 0.10.0")
        expect(updated_manifest_content).not_to include("version: ~> 0.13.0")
      end
    end

    context "with development dependencies" do
      let(:content) do
        <<~CONTENT
          dependencies:
            db:
              github: crystal-lang/crystal-db
              version: ~> 0.10.0
          development_dependencies:
            db:
              github: crystal-lang/crystal-db
              version: ~> 0.10.0
        CONTENT
      end

      let(:new_requirements) do
        [{ requirement: "~> 0.13.0", groups: ["development"], file: "shard.yml", source: nil }]
      end

      it "updates only development dependency versions" do
        expect(updated_manifest_content).to include("version: ~> 0.13.0")
        expect(updated_manifest_content).to include("version: ~> 0.10.0")
      end
    end

    context "with Version object as requirement" do
      let(:new_requirements) do
        [{ requirement: Dependabot::Shards::Version.new("0.13.0"), groups: ["runtime"], file: "shard.yml", source: nil }]
      end

      it "converts Version object to string" do
        expect(updated_manifest_content).to include("version: 0.13.0")
        expect(updated_manifest_content).not_to include("version: ~> 0.10.0")
      end
    end

    context "with no requirements to update" do
      let(:new_requirements) { [] }

      it "returns content unchanged" do
        expect(updated_manifest_content).to eq(content)
      end
    end
  end
end