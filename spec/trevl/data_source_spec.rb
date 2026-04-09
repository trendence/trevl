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

    it "instantiates classes when registered as Class" do
      described_class.register("static_class", Trevl::DataSource::Static)
      source = described_class.for("static_class", data: {"x" => [1]})

      expect(source).to be_a(Trevl::DataSource::Static)
      expect(source.fetch("x")["data"]).to eq([1])
    end
  end

  describe ".reset!" do
    it "clears all registered sources" do
      described_class.register("temp", Trevl::DataSource::Static.new(data: {}))
      described_class.reset!
      expect { described_class.for("temp") }.to raise_error(Trevl::DataSourceError)
    end
  end
end
