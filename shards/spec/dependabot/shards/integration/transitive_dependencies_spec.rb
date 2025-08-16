# typed: false
# frozen_string_literal: true

require "spec_helper"
require "dependabot/dependency"
require "dependabot/shards"

RSpec.describe "Transitive dependency updates", :vcr do
  let(:dependency_files) { project_dependency_files("transitive_dependencies") }
  let(:parser) { Dependabot::Shards::FileParser.new(dependency_files: dependency_files, source: source) }
  let(:source) do
    Dependabot::Source.new(
      provider: "github",
      repo: "example/repo",
      directory: "/"
    )
  end

  describe "parsing transitive dependencies" do
    subject(:dependencies) { parser.parse }

    it "identifies transitive dependencies correctly" do
      transitive_deps = dependencies.reject(&:top_level?)
      expect(transitive_deps.map(&:name)).to include("athena-serializer", "athena-validator")
    end

    it "marks transitive dependencies with subdependency_metadata" do
      athena_serializer = dependencies.find { |d| d.name == "athena-serializer" }
      expect(athena_serializer).not_to be_nil
      expect(athena_serializer.subdependency_metadata).to eq([{ production: true }])
    end

    it "correctly identifies production vs development transitive dependencies" do
      # Dependencies of "athena" (production) should be marked as production
      athena_serializer = dependencies.find { |d| d.name == "athena-serializer" }
      expect(athena_serializer&.subdependency_metadata&.first&.dig(:production)).to be true
    end
  end

  describe "updating transitive dependencies" do
    let(:dependency) do
      dependencies.find { |d| d.name == "athena-serializer" && !d.top_level? }
    end
    let(:dependencies) { parser.parse }

    context "when a new version is available" do
      let(:update_checker) do
        Dependabot::Shards::UpdateChecker.new(
          dependency: dependency,
          dependency_files: dependency_files,
          credentials: [],
          ignored_versions: [],
          security_advisories: []
        )
      end

      before do
        # Mock the subdependency resolver to return a newer version
        allow_any_instance_of(Dependabot::Shards::UpdateChecker::SubdependencyVersionResolver)
          .to receive(:latest_resolvable_version)
          .and_return(Dependabot::Shards::Version.new("0.4.2"))

        # Mock latest_version for comparison
        allow(update_checker).to receive(:latest_version).and_return("0.4.2")
      end

      it "can update transitive dependencies" do
        expect(update_checker.can_update?(requirements_to_unlock: :own)).to be true
        expect(update_checker.latest_resolvable_version.to_s).to eq("0.4.2")
      end

      it "creates an updated dependency with informational metadata" do
        updated_deps = update_checker.updated_dependencies(requirements_to_unlock: :own)
        expect(updated_deps).not_to be_empty
        
        updated_dep = updated_deps.first
        expect(updated_dep.name).to eq("athena-serializer")
        expect(updated_dep.version).to eq("0.4.2")
        expect(updated_dep.previous_version).to eq("0.3.0")
        expect(updated_dep.requirements).to be_empty
      end
    end
  end

  describe "file updating for transitive dependencies" do
    let(:dependency) do
      Dependabot::Dependency.new(
        name: "athena-serializer",
        version: "0.4.2",
        previous_version: "0.3.0",
        requirements: [],
        package_manager: "shards",
        subdependency_metadata: [{ production: true }]
      )
    end

    let(:file_updater) do
      Dependabot::Shards::FileUpdater.new(
        dependencies: [dependency],
        dependency_files: dependency_files,
        credentials: []
      )
    end

    before do
      # Mock the lockfile updater to return updated content
      allow_any_instance_of(Dependabot::Shards::FileUpdater::LockfileUpdater)
        .to receive(:updated_lockfile_content)
        .and_return(updated_lockfile_content)
    end

    let(:updated_lockfile_content) do
      <<~LOCKFILE
        version: 2.0
        shards:
          ameba:
            git: https://github.com/crystal-ameba/ameba.git
            version: 1.6.4

          athena:
            git: https://github.com/athena-framework/framework.git
            version: 0.20.1

          athena-serializer:
            git: https://github.com/athena-framework/serializer.git
            version: 0.4.2

          athena-validator:
            git: https://github.com/athena-framework/validator.git
            version: 0.1.3
      LOCKFILE
    end

    it "only updates the lockfile for transitive dependencies" do
      updated_files = file_updater.updated_dependency_files

      # Should only update lockfile, not manifest
      expect(updated_files.length).to eq(1)
      expect(updated_files.first.name).to eq("shard.lock")
      expect(updated_files.first.content).to include("athena-serializer:")
      expect(updated_files.first.content).to include("version: 0.4.2")
    end

    it "preserves manifest content unchanged" do
      original_manifest = dependency_files.find { |f| f.name == "shard.yml" }
      updated_files = file_updater.updated_dependency_files
      
      # Manifest should not be included in updated files for transitive dependencies
      manifest_update = updated_files.find { |f| f.name == "shard.yml" }
      expect(manifest_update).to be_nil
    end
  end
end