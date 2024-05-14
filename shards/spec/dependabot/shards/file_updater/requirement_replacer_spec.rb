# typed: false
# frozen_string_literal: true

require "spec_helper"
require "dependabot/shards/file_updater/requirement_replacer"

RSpec.describe Dependabot::Shards::FileUpdater::RequirementReplacer do
  let(:replacer) do
    described_class.new(
      content: content,
      declaration: declaration,
      old_requirement: old_requirement,
      new_requirement: new_requirement
    )
  end

  describe "#updated_content" do
    subject(:updated_content) { replacer.updated_content }

    context "with a simple version requirement" do
      let(:content) do
        <<~CONTENT
          dependencies:
            db:
              github: crystal-lang/crystal-db
              version: ~> 0.10.0
        CONTENT
      end
      let(:declaration) { /version: ~> 0\.10\.0/ }
      let(:old_requirement) { "~> 0.10.0" }
      let(:new_requirement) { "~> 0.13.0" }

      it "replaces the requirement" do
        expect(updated_content).to include("version: ~> 0.13.0")
        expect(updated_content).not_to include("version: ~> 0.10.0")
      end
    end

    context "with exact version requirement" do
      let(:content) do
        <<~CONTENT
          dependencies:
            db:
              github: crystal-lang/crystal-db
              version: 0.10.0
        CONTENT
      end
      let(:declaration) { /version: 0\.10\.0/ }
      let(:old_requirement) { "0.10.0" }
      let(:new_requirement) { "0.13.0" }

      it "replaces the exact version" do
        expect(updated_content).to include("version: 0.13.0")
        expect(updated_content).not_to include("version: 0.10.0")
      end
    end

    context "with multiple occurrences of the same requirement" do
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
      let(:declaration) { /version: ~> 0\.10\.0/ }
      let(:old_requirement) { "~> 0.10.0" }
      let(:new_requirement) { "~> 0.13.0" }

      it "replaces all occurrences" do
        expect(updated_content.scan("version: ~> 0.13.0").count).to eq(2)
        expect(updated_content).not_to include("version: ~> 0.10.0")
      end
    end

    context "with complex declaration pattern" do
      let(:content) do
        <<~CONTENT
          dependencies:
            db:
              github: crystal-lang/crystal-db
              version: ">= 0.10.0, < 0.11.0"
        CONTENT
      end
      let(:declaration) { /version: ">= 0\.10\.0, < 0\.11\.0"/ }
      let(:old_requirement) { ">= 0.10.0, < 0.11.0" }
      let(:new_requirement) { ">= 0.13.0, < 0.14.0" }

      it "replaces complex version constraints" do
        expect(updated_content).to include('version: ">= 0.13.0, < 0.14.0"')
        expect(updated_content).not_to include('version: ">= 0.10.0, < 0.11.0"')
      end
    end

    context "when declaration doesn't match content" do
      let(:content) do
        <<~CONTENT
          dependencies:
            db:
              github: crystal-lang/crystal-db
              version: ~> 0.10.0
        CONTENT
      end
      let(:declaration) { /version: ~> 0\.99\.0/ }
      let(:old_requirement) { "~> 0.99.0" }
      let(:new_requirement) { "~> 0.13.0" }

      it "returns content unchanged" do
        expect(updated_content).to eq(content)
      end
    end

    context "when old_requirement doesn't match within declaration" do
      let(:content) do
        <<~CONTENT
          dependencies:
            db:
              github: crystal-lang/crystal-db
              version: ~> 0.10.0
        CONTENT
      end
      let(:declaration) { /version: ~> 0\.10\.0/ }
      let(:old_requirement) { "~> 0.99.0" }
      let(:new_requirement) { "~> 0.13.0" }

      it "returns content unchanged when substitution target not found" do
        expect(updated_content).to eq(content)
      end
    end
  end
end