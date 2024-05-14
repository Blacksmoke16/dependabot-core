# typed: false
# frozen_string_literal: true

require "spec_helper"
require "dependabot/shards/file_fetcher"
require_common_spec "file_fetchers/shared_examples_for_file_fetchers"

RSpec.describe Dependabot::Shards::FileFetcher do
  it_behaves_like "a dependency file fetcher"

  let(:directory) { "/" }
  let(:source) do
    Dependabot::Source.new(
      provider: "github",
      repo: "crystal-lang/shards",
      directory: directory
    )
  end
  let(:file_fetcher_instance) do
    described_class.new(source: source, credentials: credentials)
  end
  let(:url) { "https://api.github.com/repos/crystal-lang/shards/contents/" }
  let(:credentials) do
    [{
      "type" => "git_source",
      "host" => "github.com",
      "username" => "x-access-token",
      "password" => "token"
    }]
  end

  before do
    allow(file_fetcher_instance).to receive(:commit).and_return("sha")

    stub_request(:get, url + "?ref=sha")
      .with(headers: { "Authorization" => "token token" })
      .to_return(
        status: 200,
        body: fixture("github", "contents_shard_repo.json"),
        headers: { "content-type" => "application/json" }
      )
    stub_request(:get, url + "shard.yml?ref=sha")
      .with(headers: { "Authorization" => "token token" })
      .to_return(
        status: 200,
        body: fixture("github", "shard_yml_content.json"),
        headers: { "content-type" => "application/json" }
      )
    stub_request(:get, url + "shard.lock?ref=sha")
      .with(headers: { "Authorization" => "token token" })
      .to_return(
        status: 200,
        body: fixture("github", "shard_lock_content.json"),
        headers: { "content-type" => "application/json" }
      )
  end

  it "fetches shard.yml and shard.lock" do
    expect(file_fetcher_instance.files.map(&:name))
      .to match_array(%w(shard.yml shard.lock))
  end

  it "provides the shards version" do
    expect(file_fetcher_instance.ecosystem_versions).to eq({
      package_managers: { "shards" => "2.0" }
    })
  end

  context "without a shard.lock" do
    before do
      stub_request(:get, url + "?ref=sha")
        .with(headers: { "Authorization" => "token token" })
        .to_return(
          status: 200,
          body: fixture("github", "contents_shard_repo_no_lockfile.json"),
          headers: { "content-type" => "application/json" }
        )
      stub_request(:get, url + "shard.lock?ref=sha")
        .with(headers: { "Authorization" => "token token" })
        .to_return(status: 404)
    end

    it "fetches the composer.json" do
    expect(file_fetcher_instance.files.map(&:name))
      .to match_array(%w(shard.yml))    end

    it "provides the composer version" do
      expect(file_fetcher_instance.ecosystem_versions).to eq({
        package_managers: { "shards" => "2.0" }
      })
    end
  end

  context "without a shard.yml" do
    before do
      stub_request(:get, url + "shard.yml?ref=sha")
        .with(headers: { "Authorization" => "token token" })
        .to_return(status: 404)
    end

    it "raises a helpful error" do
      expect { file_fetcher_instance.files }
        .to raise_error(Dependabot::DependencyFileNotFound)
    end
  end
end
