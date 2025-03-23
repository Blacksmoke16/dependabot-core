# typed: false
# frozen_string_literal: true

require "dependabot/shards/package_manager"
require "dependabot/ecosystem"
require "spec_helper"

RSpec.describe Dependabot::Shards::PackageManager do
  let(:package_manager) { described_class.new(version) }

  let(:version) { "0.19.1" }

  describe "#initialize" do
    context "when version is a String" do
      it "sets the version correctly" do
        expect(package_manager.version).to eq(version)
      end

      it "sets the name correctly" do
        expect(package_manager.name).to eq("shards")
      end
    end
  end

  describe "#version" do
    it "returns the version" do
      expect(package_manager.version.to_s).to eq version
    end
  end

  describe "#name" do
    it "returns the name" do
      expect(package_manager.name).to eq(Dependabot::Shards::PackageManager::NAME)
    end
  end

  describe "#deprecated_versions" do
    it "returns deprecated versions" do
      expect(package_manager.deprecated_versions).to eq(Dependabot::Shards::PackageManager::DEPRECATED_VERSIONS)
    end
  end

  describe "#supported_versions" do
    it "returns supported versions" do
      expect(package_manager.supported_versions).to eq(Dependabot::Shards::PackageManager::SUPPORTED_VERSIONS)
    end
  end
end
