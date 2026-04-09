# frozen_string_literal: true

RSpec.describe Trevl::Processor do
  describe "#components" do
    it "parses a YAML string with components" do
      yaml = <<~YAML
        components:
        - id: test_chart
          type: chart
          api: static
      YAML

      processor = Trevl::Processor.new(yaml)
      expect(processor.components).to be_an(Array)
      expect(processor.components.first["id"]).to eq("test_chart")
    end

    it "supports bare array of components" do
      yaml = <<~YAML
        - id: test_chart
          type: chart
          api: static
      YAML

      processor = Trevl::Processor.new(yaml)
      expect(processor.components.first["id"]).to eq("test_chart")
    end
  end

  describe "template resolution" do
    it "merges template into component" do
      Trevl.template_store.register("my_template", {
        "highchartsData" => {
          "chart" => {"type" => "bar"},
          "colors" => ["#003F85"]
        }
      })

      yaml = <<~YAML
        components:
        - id: test
          type: chart
          template: my_template
          highchartsData:
            chart:
              height: 400
      YAML

      processor = Trevl::Processor.new(yaml)
      component = processor.components.first

      expect(component["highchartsData"]["chart"]["type"]).to eq("bar")
      expect(component["highchartsData"]["chart"]["height"]).to eq(400)
      expect(component["highchartsData"]["colors"]).to eq(["#003F85"])
      expect(component).not_to have_key("template")
    end

    it "component values override template values" do
      Trevl.template_store.register("base", {"highchartsData" => {"chart" => {"type" => "bar"}}})

      yaml = <<~YAML
        components:
        - id: test
          type: chart
          template: base
          highchartsData:
            chart:
              type: column
      YAML

      processor = Trevl::Processor.new(yaml)
      expect(processor.components.first["highchartsData"]["chart"]["type"]).to eq("column")
    end
  end

  describe "error handling" do
    it "raises ParseError for invalid YAML" do
      expect { Trevl::Processor.new("- [invalid: yaml: :") }.to raise_error(Trevl::ParseError)
    end
  end
end
