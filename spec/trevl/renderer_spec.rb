# frozen_string_literal: true

RSpec.describe Trevl::Renderer do
  before do
    Trevl::DataSource.register("static", Trevl::DataSource::Static.new(
      data: {
        "salary" => {
          "data" => [
            {"percentile" => "q10", "value" => 30000},
            {"percentile" => "q50", "value" => 45000},
            {"percentile" => "q90", "value" => 72000}
          ],
          "meta" => {"total_results" => 3}
        }
      }
    ))
  end

  describe "#render" do
    it "renders a chart component with static data" do
      component = {
        "id" => "salary_chart",
        "type" => "chart",
        "api" => "static",
        "highchartsData" => {
          "chart" => {"type" => "bar"},
          "series" => [
            {
              "name" => "Salary",
              "data" => {
                "x" => "$salary.data.percentile",
                "y" => "$salary.data.value"
              }
            }
          ]
        }
      }

      result = described_class.new(component).render

      expect(result["type"]).to eq("chart")
      expect(result["highchartsData"]["series"].first["data"].length).to eq(3)
      expect(result["highchartsData"]["series"].first["data"][1]["y"]).to eq(45000)
    end

    it "renders a text component without API" do
      component = {
        "id" => "header",
        "type" => "text",
        "text" => "Hello World"
      }

      result = described_class.new(component).render
      expect(result["type"]).to eq("text")
      expect(result["text"]).to eq("Hello World")
    end

    it "renders a score component" do
      component = {
        "id" => "total_score",
        "type" => "score",
        "api" => "static",
        "display" => {
          "value" => "$salary.meta.total_results",
          "unit" => ""
        }
      }

      result = described_class.new(component).render
      expect(result["type"]).to eq("score")
      expect(result["display"]["value"]).to eq(3)
    end

    it "returns nil for unknown types" do
      result = described_class.new({"id" => "x", "type" => "unknown"}).render
      expect(result).to be_nil
    end
  end

  describe "computed fields" do
    it "applies JavaScript computed fields to rows" do
      component = {
        "id" => "chart",
        "type" => "chart",
        "api" => "static",
        "computed" => [
          {"name" => "label", "code" => '"Gehalt"'},
          {
            "name" => "doubled",
            "arguments" => {"val" => "$salary.data.value"},
            "code" => "val * 2"
          }
        ],
        "highchartsData" => {
          "series" => [{"data" => {"y" => "$salary.data.doubled"}}]
        }
      }

      result = described_class.new(component).render
      expect(result["highchartsData"]["series"].first["data"][1]["y"]).to eq(90000)
    end
  end

  describe "postprocess" do
    it "applies postprocess JavaScript to filter/sort data" do
      component = {
        "id" => "chart",
        "type" => "chart",
        "api" => "static",
        "postprocess" => "$result = $result.filter(function(r) { return r.value > 40000; })",
        "highchartsData" => {
          "series" => [{"data" => {"y" => "$salary.data.value"}}]
        }
      }

      result = described_class.new(component).render
      expect(result["highchartsData"]["series"].first["data"].length).to eq(2)
    end
  end

  describe ".parse_trevl_ref" do
    it "parses endpoint.data.field" do
      parsed = described_class.parse_trevl_ref("salary.data.q50")
      expect(parsed[:endpoint]).to eq("salary")
      expect(parsed[:scope]).to eq(:data)
      expect(parsed[:keys]).to eq(["q50"])
    end

    it "parses endpoint.meta.field" do
      parsed = described_class.parse_trevl_ref("salary.meta.total")
      expect(parsed[:endpoint]).to eq("salary")
      expect(parsed[:scope]).to eq(:meta)
      expect(parsed[:keys]).to eq(["total"])
    end

    it "parses resource.endpoint.data.field" do
      parsed = described_class.parse_trevl_ref("surveys.distribution.data.share")
      expect(parsed[:resource]).to eq("surveys")
      expect(parsed[:endpoint]).to eq("distribution")
      expect(parsed[:scope]).to eq(:data)
      expect(parsed[:keys]).to eq(["share"])
    end
  end
end
