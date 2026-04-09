# frozen_string_literal: true

RSpec.describe Trevl::DataSource do
  describe ".register / .for" do
    it "registers and retrieves a data source instance" do
      source = Trevl::DataSource::Static.new(data: {})
      described_class.register("test", source)

      expect(described_class.for("test")).to eq(source)
    end

    it "is case-insensitive" do
      source = Trevl::DataSource::Static.new(data: {})
      described_class.register("MySource", source)

      expect(described_class.for("mysource")).to eq(source)
    end

    it "raises DataSourceError for unknown source" do
      expect { described_class.for("nonexistent") }.to raise_error(
        Trevl::DataSourceError, /No data source registered for 'nonexistent'/
      )
    end

    it "lists available sources in error message" do
      described_class.register("alpha", Trevl::DataSource::Static.new(data: {}))
      described_class.register("beta", Trevl::DataSource::Static.new(data: {}))

      expect { described_class.for("missing") }.to raise_error(
        Trevl::DataSourceError, /Available: alpha, beta/
      )
    end

    it "instantiates classes when registered as Class" do
      described_class.register("static_class", Trevl::DataSource::Static)
      source = described_class.for("static_class", data: {"x" => [1]})

      expect(source).to be_a(Trevl::DataSource::Static)
      expect(source.fetch("x")["data"]).to eq([1])
    end
  end

  describe ".all" do
    it "returns an empty array when no sources are registered" do
      expect(described_class.all).to eq([])
    end

    it "returns all registered sources with name and type" do
      described_class.register("demo", Trevl::DataSource::Static.new(data: {}))
      described_class.register("api", Trevl::DataSource::Api.new(base_url: "https://example.com/v1"))

      result = described_class.all
      expect(result.length).to eq(2)

      demo = result.find { |s| s[:name] == "demo" }
      expect(demo[:type]).to eq("Static")
      expect(demo[:source]).to be_a(Trevl::DataSource::Static)

      api = result.find { |s| s[:name] == "api" }
      expect(api[:type]).to eq("Api")
      expect(api[:base_url]).to eq("https://example.com/v1")
    end

    it "includes base_url for Api sources" do
      described_class.register("myapi", Trevl::DataSource::Api.new(base_url: "https://api.test.com"))

      info = described_class.all.first
      expect(info[:base_url]).to eq("https://api.test.com")
    end

    it "includes url for Cube sources" do
      described_class.register("cube", Trevl::DataSource::Cube.new(url: "https://cube.test.com/cubejs-api/v1"))

      info = described_class.all.first
      expect(info[:url]).to eq("https://cube.test.com/cubejs-api/v1")
    end

    it "handles Class registrations" do
      described_class.register("static_class", Trevl::DataSource::Static)

      info = described_class.all.first
      expect(info[:type]).to eq("Static")
      expect(info[:source]).to eq(Trevl::DataSource::Static)
    end
  end

  describe ".names" do
    it "returns registered source names" do
      described_class.register("alpha", Trevl::DataSource::Static.new(data: {}))
      described_class.register("beta", Trevl::DataSource::Static.new(data: {}))

      expect(described_class.names).to contain_exactly("alpha", "beta")
    end

    it "returns empty array when nothing registered" do
      expect(described_class.names).to eq([])
    end
  end

  describe ".reset!" do
    it "clears all registered sources" do
      described_class.register("temp", Trevl::DataSource::Static.new(data: {}))
      described_class.reset!
      expect { described_class.for("temp") }.to raise_error(Trevl::DataSourceError)
      expect(described_class.all).to eq([])
      expect(described_class.names).to eq([])
    end
  end
end
