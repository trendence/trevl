# frozen_string_literal: true

RSpec.describe Trevl::DataSource::Static do
  let(:data) do
    {
      "salary" => {
        "data" => [{"q50" => 45000}],
        "meta" => {"count" => 1}
      },
      "items" => [{"name" => "A"}, {"name" => "B"}]
    }
  end

  subject { described_class.new(data: data) }

  it "returns hash data with data/meta structure" do
    result = subject.fetch("salary")
    expect(result["data"]).to eq([{"q50" => 45000}])
    expect(result["meta"]).to eq({"count" => 1})
  end

  it "wraps array data in standard structure" do
    result = subject.fetch("items")
    expect(result["data"]).to eq([{"name" => "A"}, {"name" => "B"}])
    expect(result["meta"]).to eq({})
  end

  it "returns empty result for unknown endpoints" do
    result = subject.fetch("unknown")
    expect(result["data"]).to eq([])
    expect(result["meta"]).to eq({})
  end
end
