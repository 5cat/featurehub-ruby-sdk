# frozen_string_literal: true

require "json"

RSpec.describe FeatureHub::Sdk::FeatureState do
  let(:repo) { instance_double(FeatureHub::Sdk::FeatureHubRepository) }

  def raw_full_feature
    <<~END_JSON
      {
        "id": "227dc2e8-59e8-424a-b510-328ef52010f7",
        "key": "SUBMIT_COLOR_BUTTON",
        "l": true,
        "version": 28,
        "type": "STRING",
        "value": "orange",
        "strategies": [
          {
            "id": "7000b097-3fcb-4cfb-bd7c-be1640fe0503",
            "value": "green",
            "attributes": [
              {
                "conditional": "EQUALS",
                "fieldName": "country",
                "values": [
                  "australia"
                ],
                "type": "STRING"
              }
            ]
          }
        ]
      }
    END_JSON
  end

  it "recognizes the correct state of a complex feature" do
    state = JSON.parse(raw_full_feature)
    fs = FeatureHub::Sdk::FeatureState.new(state["key"].to_sym, repo)
    fs.update_feature_state(state)
    expect(fs.version).to eq(28)
  end

  describe "with no interceptors" do
    before do
      expect(repo).to receive(:find_interceptor).at_least(:once).and_return(nil)
    end

    it "should allow me to create an empty feature" do
      f = FeatureHub::Sdk::FeatureState.new(:blah, repo)

      expect(f.locked?).to eq(false)
      expect(f.exists?).to eq(false)
      expect(f.flag).to eq(nil)
      expect(f.version).to eq(-1)
      expect(f.enabled?).to eq(false)
    end
  end

  it "should allow me to create an empty feature and then update it with locked data" do
    f = FeatureHub::Sdk::FeatureState.new(:blah, repo)
    data = JSON.parse('{"id": 123, "key": "blah", "version": 1, "value": false, "type": "BOOLEAN", "l": true}')
    expect(f.exists?).to eq(false)
    f.update_feature_state(data)
    expect(f.exists?).to eq(true)
    expect(f.flag).to eq(false)
    expect(f.boolean).to eq(false)
    expect(f.value).to eq(false)
    expect(f.version).to eq(1)
    expect(f.enabled?).to eq(false)
    expect(f.set?).to eq(true)
    expect(f.locked?).to eq(true)
    expect(f.id).to eq(123)
    expect(f.number).to eq(nil)
    expect(f.string).to eq(nil)
    expect(f.raw_json).to eq(nil)
    expect(f.feature_type).to eq("BOOLEAN")
    expect(f.feature_state).to eq(data)
  end

  it "decodes numbers properly" do
    data = JSON.parse('{"id": 123, "key": "blah", "version": 1, "value": 725.43, "type": "NUMBER", "l": true}')
    f = FeatureHub::Sdk::FeatureState.new(:blah, repo, data)
    expect(f.number).to eq(725.43)
    expect(f.boolean).to eq(nil)
    expect(f.flag).to eq(nil)
    expect(f.string).to eq(nil)
    expect(f.raw_json).to eq(nil)
    expect(f.enabled?).to eq(false)
    expect(f.set?).to eq(true)
  end

  it "decodes strings properly" do
    data = JSON.parse('{"id": 123, "key": "blah", "version": 1, "value": "djelif", "type": "STRING", "l": true}')
    f = FeatureHub::Sdk::FeatureState.new(:blah, repo, data)
    expect(f.string).to eq("djelif")
    expect(f.number).to eq(nil)
    expect(f.boolean).to eq(nil)
    expect(f.flag).to eq(nil)
    expect(f.raw_json).to eq(nil)
    expect(f.enabled?).to eq(false)
    expect(f.set?).to eq(true)
  end

  it "decodes json properly" do
    data = JSON.parse('{"id": 123, "key": "blah", "version": 1, "value": "{}", "type": "JSON", "l": true}')
    f = FeatureHub::Sdk::FeatureState.new(:blah, repo, data)
    expect(f.string).to eq(nil)
    expect(f.raw_json).to eq("{}")
    expect(f.number).to eq(nil)
    expect(f.boolean).to eq(nil)
    expect(f.flag).to eq(nil)
    expect(f.enabled?).to eq(false)
    expect(f.set?).to eq(true)
  end

  it "handles unset features properly" do
    data = JSON.parse('{"id": 123, "key": "blah", "version": 1, "type": "JSON", "l": true}')
    f = FeatureHub::Sdk::FeatureState.new(:blah, repo, data)
    expect(f.string).to eq(nil)
    expect(f.raw_json).to eq(nil)
    expect(f.number).to eq(nil)
    expect(f.boolean).to eq(nil)
    expect(f.flag).to eq(nil)
    expect(f.enabled?).to eq(false)
    expect(f.set?).to eq(false)
  end

  describe "it has a known set of data and feature" do
    let(:data) { JSON.parse('{"id": 123, "key": "blah", "version": 1, "value": "ruby", "type": "STRING", "l": true}') }
    let(:f) { FeatureHub::Sdk::FeatureState.new(:blah, repo, data) }

    describe "feature has a context" do
      let(:ctx) { instance_double(FeatureHub::Sdk::ClientContext) }

      it "asks for client evaluation when a context is provided but no match exists should return default value" do
        expect(repo).to receive(:apply).and_return(FeatureHub::Sdk::Impl::Applied.new(false, nil))
        expect(f.with_context(ctx).string).to eq("ruby")
        expect(f.with_context(ctx).exists?).to be(true)
        expect(f.with_context(ctx).version).to be(1)
        expect(f.with_context(ctx).locked?).to be(true)
      end

      it "asks for client evaluation but a match is provided and it should return match" do
        expect(repo).to receive(:apply).and_return(FeatureHub::Sdk::Impl::Applied.new(true, "python"))
        expect(f.with_context(ctx).string).to eq("python")
      end
    end

    describe "it has an interceptor" do
      it "should be able to decide an intercepted value" do
        f.feature_state["l"] = false  # override the lock to make testing less noisy
        expect(repo).to receive(:find_interceptor).with(:blah).at_least(:once)
                                                  .and_return(FeatureHub::Sdk::InterceptorValue.new("clot"))
        expect(f.string).to eq("clot")
      end
    end
  end
end
