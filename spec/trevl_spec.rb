# frozen_string_literal: true

RSpec.describe Trevl do
  it "has a version number" do
    expect(Trevl::VERSION).not_to be_nil
    expect(Trevl::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
  end

  describe ".configure" do
    it "allows setting a custom logger" do
      logger = Logger.new($stdout)
      Trevl.configure { |c| c.logger = logger }
      expect(Trevl.logger).to eq(logger)
    end

    it "provides a default logger" do
      expect(Trevl.logger).to be_a(Logger)
    end
  end

  describe ".template_store" do
    it "returns the configured template store" do
      expect(Trevl.template_store).to be_a(Trevl::TemplateStore)
    end

    it "allows registering and finding templates" do
      Trevl.template_store.register("test", {"chart" => {"type" => "bar"}})
      expect(Trevl.template_store.find("test")).to eq({"chart" => {"type" => "bar"}})
    end
  end

  describe ".parse" do
    it "returns a Processor instance" do
      processor = Trevl.parse("components:\n- id: c1\n  type: text")
      expect(processor).to be_a(Trevl::Processor)
      expect(processor.components.first["id"]).to eq("c1")
    end
  end

  describe ".render" do
    before do
      Trevl::DataSource.register("static", Trevl::DataSource::Static.new(
        data: {"ep" => {"data" => [{"x" => "A", "y" => 10}], "meta" => {}}}
      ))
    end

    it "parses YAML and renders all components" do
      results = Trevl.render(<<~YAML)
        components:
        - id: c1
          type: chart
          api: static
          highchartsData:
            series:
            - data:
                x: "$ep.data.x"
                y: "$ep.data.y"
      YAML

      expect(results.length).to eq(1)
      expect(results.first["type"]).to eq("chart")
      expect(results.first["highchartsData"]["series"].first["data"].first["y"]).to eq(10)
    end

    it "skips components that render to nil" do
      results = Trevl.render(<<~YAML)
        components:
        - id: c1
          type: unknown_type
      YAML

      expect(results).to be_empty
    end

    it "renders with per-call data sources instead of the registry" do
      source = Trevl::DataSource::Static.new(
        data: {"ep" => {"data" => [{"x" => "B", "y" => 42}], "meta" => {}}}
      )

      results = Trevl.render(<<~YAML, data_sources: {"inline" => source})
        components:
        - id: c1
          type: chart
          api: inline
          highchartsData:
            series:
            - data:
                x: "$ep.data.x"
                y: "$ep.data.y"
      YAML

      expect(results.first["highchartsData"]["series"].first["data"].first["y"]).to eq(42)
      expect(Trevl::DataSource.names).not_to include("inline")
    end

    it "renders with inline data and no api key at all" do
      results = Trevl.render(<<~YAML, data: {"ep" => [{"x" => "C", "y" => 7}]})
        components:
        - id: c1
          type: chart
          highchartsData:
            series:
            - data:
                x: "$ep.data.x"
                y: "$ep.data.y"
      YAML

      expect(results.first["highchartsData"]["series"].first["data"].first["y"]).to eq(7)
      expect(Trevl::DataSource.names).to eq(["static"])
    end
  end

  describe ".reset!" do
    it "resets configuration to defaults" do
      Trevl.configure { |c| c.logger = Logger.new($stdout) }
      Trevl.reset!
      expect(Trevl.configuration).to be_a(Trevl::Configuration)
    end
  end
end
