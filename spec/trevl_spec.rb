# frozen_string_literal: true

RSpec.describe Trevl do
  it "has a version number" do
    expect(Trevl::VERSION).not_to be_nil
  end

  describe ".configure" do
    it "allows setting a logger" do
      logger = Logger.new($stdout)
      Trevl.configure { |c| c.logger = logger }
      expect(Trevl.logger).to eq(logger)
    end
  end

  describe ".render" do
    before do
      Trevl::DataSource.register("static", Trevl::DataSource::Static.new(
        data: {"endpoint" => {"data" => [{"x" => "A", "y" => 10}], "meta" => {}}}
      ))
    end

    it "parses YAML and renders all components" do
      yaml = <<~YAML
        components:
        - id: c1
          type: chart
          api: static
          highchartsData:
            series:
            - data:
                x: "$endpoint.data.x"
                y: "$endpoint.data.y"
      YAML

      results = Trevl.render(yaml)
      expect(results.length).to eq(1)
      expect(results.first["type"]).to eq("chart")
    end
  end
end
