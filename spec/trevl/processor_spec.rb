# frozen_string_literal: true

RSpec.describe Trevl::Processor do
  describe "#components" do
    it "parses a YAML string with components key" do
      processor = described_class.new(<<~YAML)
        components:
        - id: chart_1
          type: chart
          api: myapi
        - id: score_1
          type: score
      YAML

      expect(processor.components).to be_an(Array)
      expect(processor.components.length).to eq(2)
      expect(processor.components.first["id"]).to eq("chart_1")
      expect(processor.components.last["type"]).to eq("score")
    end

    it "supports bare array of components (no wrapper key)" do
      processor = described_class.new(<<~YAML)
        - id: chart_1
          type: chart
      YAML

      expect(processor.components.first["id"]).to eq("chart_1")
    end

    it "preserves all component fields" do
      processor = described_class.new(<<~YAML)
        components:
        - id: full
          type: chart
          api: myapi
          api-parameters:
            profession:
              id: "43104"
          postprocess: |
            $result = $result.slice(0, 5);
          highchartsData:
            chart:
              type: bar
            series:
            - name: Test
              data:
                y: "$endpoint.data.value"
      YAML

      comp = processor.components.first
      expect(comp["api"]).to eq("myapi")
      expect(comp["api-parameters"]["profession"]["id"]).to eq("43104")
      expect(comp["postprocess"]).to include("slice(0, 5)")
      expect(comp["highchartsData"]["chart"]["type"]).to eq("bar")
    end
  end

  describe "#valid?" do
    it "returns true for valid YAML" do
      processor = described_class.new("components:\n- id: c1\n  type: text")
      expect(processor).to be_valid
    end
  end

  describe "#component_yaml_content" do
    it "returns components as YAML string" do
      processor = described_class.new("components:\n- id: c1\n  type: text")
      yaml_out = processor.component_yaml_content
      parsed = YAML.safe_load(yaml_out, permitted_classes: [Hash], aliases: true)
      expect(parsed.first["id"]).to eq("c1")
    end
  end

  describe "template resolution" do
    it "deep-merges template into component" do
      Trevl.template_store.register("styled_bar", {
        "highchartsData" => {
          "chart" => {"type" => "bar", "backgroundColor" => "#fff"},
          "colors" => ["#003F85"],
          "plotOptions" => {"bar" => {"borderRadius" => 4}}
        }
      })

      processor = described_class.new(<<~YAML)
        components:
        - id: test
          type: chart
          template: styled_bar
          highchartsData:
            chart:
              height: 400
            title:
              text: My Chart
      YAML

      comp = processor.components.first
      expect(comp["highchartsData"]["chart"]["type"]).to eq("bar")
      expect(comp["highchartsData"]["chart"]["height"]).to eq(400)
      expect(comp["highchartsData"]["chart"]["backgroundColor"]).to eq("#fff")
      expect(comp["highchartsData"]["colors"]).to eq(["#003F85"])
      expect(comp["highchartsData"]["plotOptions"]["bar"]["borderRadius"]).to eq(4)
      expect(comp["highchartsData"]["title"]["text"]).to eq("My Chart")
      expect(comp).not_to have_key("template")
    end

    it "component values override template values at same path" do
      Trevl.template_store.register("base", {
        "highchartsData" => {"chart" => {"type" => "bar"}, "colors" => ["red"]}
      })

      processor = described_class.new(<<~YAML)
        components:
        - id: test
          type: chart
          template: base
          highchartsData:
            chart:
              type: column
      YAML

      comp = processor.components.first
      expect(comp["highchartsData"]["chart"]["type"]).to eq("column")
      expect(comp["highchartsData"]["colors"]).to eq(["red"])
    end

    it "is case-insensitive for template names" do
      Trevl.template_store.register("MyTemplate", {"foo" => "bar"})

      processor = described_class.new(<<~YAML)
        components:
        - id: test
          type: chart
          template: mytemplate
      YAML

      expect(processor.components.first["foo"]).to eq("bar")
    end

    it "ignores missing templates gracefully" do
      processor = described_class.new(<<~YAML)
        components:
        - id: test
          type: chart
          template: nonexistent
      YAML

      expect(processor.components.first["id"]).to eq("test")
      expect(processor.components.first["template"]).to eq("nonexistent")
    end
  end

  describe "error handling" do
    it "raises ParseError for invalid YAML syntax" do
      expect { described_class.new("- [invalid: yaml: :") }.to raise_error(Trevl::ParseError, /Error parsing/)
    end

    it "raises ParseError for non-hash/array content" do
      expect { described_class.new("just a string") }.to raise_error(Trevl::ParseError, /must be a Hash or Array/)
    end
  end
end
