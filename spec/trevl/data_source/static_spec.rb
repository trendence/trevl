# frozen_string_literal: true

RSpec.describe Trevl::DataSource::Static do
  let(:data) do
    {
      "salary" => {
        "data" => [{"q50" => 45000}, {"q50" => 62000}],
        "meta" => {"count" => 2, "currency" => "EUR"}
      },
      "items" => [{"name" => "A"}, {"name" => "B"}],
      "resource/endpoint" => {
        "data" => [{"value" => 100}]
      }
    }
  end

  subject { described_class.new(data: data) }

  describe "#fetch" do
    it "returns hash data with data/meta structure" do
      result = subject.fetch("salary")
      expect(result["data"]).to eq([{"q50" => 45000}, {"q50" => 62000}])
      expect(result["meta"]).to eq({"count" => 2, "currency" => "EUR"})
    end

    it "wraps plain array data in standard structure" do
      result = subject.fetch("items")
      expect(result["data"]).to eq([{"name" => "A"}, {"name" => "B"}])
      expect(result["meta"]).to eq({})
    end

    it "supports resource/endpoint composite keys" do
      result = subject.fetch("endpoint", {}, resource: "resource")
      expect(result["data"]).to eq([{"value" => 100}])
    end

    it "falls back to endpoint-only key when composite not found" do
      result = subject.fetch("salary", {}, resource: "unknown")
      expect(result["data"]).to eq([{"q50" => 45000}, {"q50" => 62000}])
    end

    it "returns empty result for unknown endpoints" do
      result = subject.fetch("nonexistent")
      expect(result["data"]).to eq([])
      expect(result["meta"]).to eq({})
    end
  end
end
