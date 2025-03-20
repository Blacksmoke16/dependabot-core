# typed: false
# frozen_string_literal: true

require "dependabot/shards/package_manager"
require "dependabot/ecosystem"
require "spec_helper"

RSpec.describe Dependabot::Shards::PackageManager do
  let(:package_manager) { described_class.new("0.19.1") }

  describe "#initialize" do
    context "when version is a String" do
      it "sets the version correctly" do
        expect(package_manager.version).to eq("0.19.1")
      end

      it "sets the name correctly" do
        expect(package_manager.name).to eq("shards")
      end
    end
  end
end
