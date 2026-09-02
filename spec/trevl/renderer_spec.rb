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
          "meta" => {"total_results" => 3, "currency" => "EUR"}
        }
      }
    ))
  end

  describe "#render — chart" do
    it "renders a bar chart with x/y series from data rows" do
      result = render_component(
        "id" => "salary_chart",
        "type" => "chart",
        "api" => "static",
        "highchartsData" => {
          "chart" => {"type" => "bar"},
          "series" => [{
            "name" => "Salary",
            "data" => {"x" => "$salary.data.percentile", "y" => "$salary.data.value"}
          }]
        }
      )

      expect(result["type"]).to eq("chart")
      series = result["highchartsData"]["series"].first
      expect(series["data"].length).to eq(3)
      expect(series["data"][0]["y"]).to eq(30000)
      expect(series["data"][1]["y"]).to eq(45000)
      expect(series["data"][2]["y"]).to eq(72000)
    end

    it "populates xAxis categories from x references" do
      result = render_component(
        "id" => "c",
        "type" => "chart",
        "api" => "static",
        "highchartsData" => {
          "series" => [{"data" => {"x" => "$salary.data.percentile", "y" => "$salary.data.value"}}]
        }
      )

      categories = result["highchartsData"]["xAxis"].first["categories"]
      expect(categories).to eq(["q10", "q50", "q90"])
    end

    it "passes through chart configuration unchanged" do
      result = render_component(
        "id" => "c",
        "type" => "chart",
        "api" => "static",
        "highchartsData" => {
          "chart" => {"type" => "column", "height" => 400},
          "title" => {"text" => "My Title"},
          "colors" => ["#003F85"],
          "series" => [{"data" => {"y" => "$salary.data.value"}}]
        }
      )

      hc = result["highchartsData"]
      expect(hc["chart"]).to eq({"type" => "column", "height" => 400})
      expect(hc["title"]).to eq({"text" => "My Title"})
      expect(hc["colors"]).to eq(["#003F85"])
    end

    it "includes display field when present" do
      result = render_component(
        "id" => "c",
        "type" => "chart",
        "api" => "static",
        "display" => {"header" => {"title" => "Salaries"}},
        "highchartsData" => {
          "series" => [{"data" => {"y" => "$salary.data.value"}}]
        }
      )

      expect(result["display"]["header"]["title"]).to eq("Salaries")
    end
  end

  describe "#render — text" do
    it "renders text component without API call" do
      result = render_component("id" => "h1", "type" => "text", "text" => "<h1>Hello</h1>")

      expect(result["type"]).to eq("text")
      expect(result["text"]).to eq("<h1>Hello</h1>")
    end

    it "includes subheader and body when present" do
      result = render_component(
        "id" => "t",
        "type" => "text",
        "subheader" => "Subtitle",
        "body" => "Body text here"
      )

      expect(result["subheader"]).to eq("Subtitle")
      expect(result["body"]).to eq("Body text here")
    end

    it "omits nil fields" do
      result = render_component("id" => "t", "type" => "text", "text" => "Hello")

      expect(result).not_to have_key("subheader")
      expect(result).not_to have_key("body")
    end
  end

  describe "#render — score" do
    it "renders score with resolved data value" do
      result = render_component(
        "id" => "s",
        "type" => "score",
        "api" => "static",
        "display" => {
          "value" => "$salary.data.value",
          "unit" => " EUR",
          "header" => {"title" => "Salary"}
        }
      )

      expect(result["type"]).to eq("score")
      expect(result["display"]["value"]).to eq(30000)
      expect(result["display"]["unit"]).to eq(" EUR")
    end

    it "resolves meta references in score" do
      result = render_component(
        "id" => "s",
        "type" => "score",
        "api" => "static",
        "display" => {"value" => "$salary.meta.total_results"}
      )

      expect(result["display"]["value"]).to eq(3)
    end
  end

  describe "#render — table" do
    it "renders table with column definitions" do
      result = render_component(
        "id" => "t",
        "type" => "table",
        "api" => "static",
        "tableData" => {
          "headers" => ["Percentile", "Value"],
          "columns" => [
            {"identifier" => "pct", "value" => "$salary.data.percentile"},
            {"identifier" => "val", "value" => "$salary.data.value"}
          ]
        }
      )

      expect(result["type"]).to eq("table")
      expect(result["tableData"]["columns"].length).to eq(3)
      expect(result["tableData"]["columns"].first["pct"]).to eq("q10")
      expect(result["tableData"]["columns"].last["val"]).to eq(72000)
    end
  end

  describe "#render — unknown type" do
    it "returns nil" do
      expect(render_component("id" => "x", "type" => "unknown")).to be_nil
    end

    it "returns nil for chart without api" do
      expect(render_component("id" => "x", "type" => "chart", "highchartsData" => {})).to be_nil
    end
  end

  describe "computed fields" do
    it "applies JavaScript expressions to each data row" do
      result = render_component(
        "id" => "c",
        "type" => "chart",
        "api" => "static",
        "computed" => [{
          "name" => "doubled",
          "arguments" => {"val" => "$salary.data.value"},
          "code" => "val * 2"
        }],
        "highchartsData" => {
          "series" => [{"data" => {"y" => "$salary.data.doubled"}}]
        }
      )

      values = result["highchartsData"]["series"].first["data"].map { |d| d["y"] }
      expect(values).to eq([60000, 90000, 144000])
    end

    it "supports string constant computed fields" do
      result = render_component(
        "id" => "c",
        "type" => "chart",
        "api" => "static",
        "computed" => [{"name" => "label", "code" => '"Salary"'}],
        "highchartsData" => {
          "series" => [{"name" => "$label", "data" => {"y" => "$salary.data.value"}}]
        }
      )

      expect(result["highchartsData"]["series"].first["name"]).to eq("Salary")
    end

    it "supports conditional logic" do
      result = render_component(
        "id" => "c",
        "type" => "chart",
        "api" => "static",
        "computed" => [{
          "name" => "color",
          "arguments" => {"v" => "$salary.data.value"},
          "code" => 'v > 50000 ? "#blue" : "#gray"'
        }],
        "highchartsData" => {
          "series" => [{"data" => {"y" => "$salary.data.value", "color" => "$color"}}]
        }
      )

      colors = result["highchartsData"]["series"].first["data"].map { |d| d["color"] }
      expect(colors).to eq(["#gray", "#gray", "#blue"])
    end

    it "chains computed fields (later fields can use earlier ones)" do
      result = render_component(
        "id" => "c",
        "type" => "chart",
        "api" => "static",
        "computed" => [
          {"name" => "thousands", "arguments" => {"v" => "$salary.data.value"}, "code" => "v / 1000"},
          {"name" => "formatted", "arguments" => {"k" => "$salary.data.thousands"}, "code" => 'k + "k"'}
        ],
        "highchartsData" => {
          "series" => [{"data" => {"y" => "$salary.data.formatted"}}]
        }
      )

      labels = result["highchartsData"]["series"].first["data"].map { |d| d["y"] }
      expect(labels).to eq(["30k", "45k", "72k"])
    end
  end

  describe "postprocess" do
    it "filters data with JavaScript" do
      result = render_component(
        "id" => "c",
        "type" => "chart",
        "api" => "static",
        "postprocess" => "$result = $result.filter(function(r) { return r.value > 40000; })",
        "highchartsData" => {
          "series" => [{"data" => {"y" => "$salary.data.value"}}]
        }
      )

      expect(result["highchartsData"]["series"].first["data"].length).to eq(2)
    end

    it "sorts data with JavaScript" do
      result = render_component(
        "id" => "c",
        "type" => "chart",
        "api" => "static",
        "postprocess" => "$result = $result.sort(function(a, b) { return a.value - b.value; })",
        "highchartsData" => {
          "series" => [{"data" => {"x" => "$salary.data.percentile", "y" => "$salary.data.value"}}]
        }
      )

      categories = result["highchartsData"]["xAxis"].first["categories"]
      expect(categories).to eq(["q10", "q50", "q90"])
    end

    it "raises RenderError for invalid JavaScript" do
      component = {
        "id" => "c",
        "type" => "chart",
        "api" => "static",
        "postprocess" => "this is not valid javascript %%%",
        "highchartsData" => {"series" => [{"data" => {"y" => "$salary.data.value"}}]}
      }

      expect { described_class.new(component).render }.to raise_error(Trevl::RenderError, /JavaScript error/)
    end

    it "warns when postprocess returns non-Array" do
      renderer = described_class.new({
        "id" => "c", "type" => "chart", "api" => "static",
        "postprocess" => '$result = "not an array"',
        "highchartsData" => {"series" => [{"data" => {"y" => "$salary.data.value"}}]}
      })
      renderer.render
      expect(renderer.warnings.any? { |w| w.include?("instead of Array") }).to be true
    end

    describe "recorded results" do
      it "leaves both readers unset when the component has no postprocess" do
        renderer = described_class.new({
          "id" => "c", "type" => "chart", "api" => "static",
          "highchartsData" => {"series" => [{"data" => {"y" => "$salary.data.value"}}]}
        })
        renderer.render

        expect(renderer.postprocess_raw_results).to be_nil
      end

      it "records what the JavaScript returned, per ref key" do
        renderer = described_class.new({
          "id" => "c", "type" => "chart", "api" => "static",
          "postprocess" => "$result = $result.filter(function(r) { return r.value > 40000; })",
          "highchartsData" => {"series" => [{"data" => {"y" => "$salary.data.value"}}]}
        })
        renderer.render

        expect(renderer.postprocess_raw_results.keys).to eq(["salary"])
        expect(renderer.postprocess_raw_results["salary"].map { |r| r["value"] }).to eq([45000, 72000])
      end

      it "records a discarded non-Array result" do
        renderer = described_class.new({
          "id" => "c", "type" => "chart", "api" => "static",
          "postprocess" => '$result = "not an array"',
          "highchartsData" => {"series" => [{"data" => {"y" => "$salary.data.value"}}]}
        })
        renderer.render

        expect(renderer.postprocess_raw_results["salary"]).to eq("not an array")
      end

      it "keeps the untouched rows when the result was discarded" do
        renderer = described_class.new({
          "id" => "c", "type" => "chart", "api" => "static",
          "postprocess" => '$result = "not an array"',
          "highchartsData" => {"series" => [{"data" => {"y" => "$salary.data.value"}}]}
        })
        renderer.render

        expect(renderer.postprocess_rows["salary"].length).to eq(3)
      end

      it "exposes the rows as postprocess left them" do
        renderer = described_class.new({
          "id" => "c", "type" => "chart", "api" => "static",
          "postprocess" => "$result = $result.filter(function(r) { return r.value > 40000; })",
          "highchartsData" => {"series" => [{"data" => {"y" => "$salary.data.value"}}]}
        })
        renderer.render

        expect(renderer.postprocess_rows["salary"].map { |r| r["value"] }).to eq([45000, 72000])
      end
    end
  end

  describe "warnings" do
    it "warns when endpoint returns no data" do
      Trevl::DataSource.register("static", Trevl::DataSource::Static.new(data: {}))

      renderer = described_class.new({
        "id" => "c", "type" => "chart", "api" => "static",
        "highchartsData" => {"series" => [{"data" => {"y" => "$missing.data.value"}}]}
      })
      renderer.render
      expect(renderer.warnings.any? { |w| w.include?("No data") }).to be true
    end
  end

  describe ".parse_trevl_ref" do
    it "parses endpoint.data.field (3 segments)" do
      parsed = described_class.parse_trevl_ref("salary.data.q50")
      expect(parsed[:endpoint]).to eq("salary")
      expect(parsed[:scope]).to eq(:data)
      expect(parsed[:keys]).to eq(["q50"])
      expect(parsed[:resource]).to be_nil
    end

    it "parses endpoint.meta.field (3 segments)" do
      parsed = described_class.parse_trevl_ref("salary.meta.total")
      expect(parsed[:endpoint]).to eq("salary")
      expect(parsed[:scope]).to eq(:meta)
      expect(parsed[:keys]).to eq(["total"])
    end

    it "parses resource.endpoint.data.field (4 segments)" do
      parsed = described_class.parse_trevl_ref("surveys.distribution.data.share")
      expect(parsed[:resource]).to eq("surveys")
      expect(parsed[:endpoint]).to eq("distribution")
      expect(parsed[:scope]).to eq(:data)
      expect(parsed[:keys]).to eq(["share"])
    end

    it "parses deep nested paths" do
      parsed = described_class.parse_trevl_ref("api.data.results.items.name")
      expect(parsed[:endpoint]).to eq("api")
      expect(parsed[:scope]).to eq(:data)
      expect(parsed[:keys]).to eq(["results", "items", "name"])
    end

    it "parses single segment as legacy ref" do
      parsed = described_class.parse_trevl_ref("fieldName")
      expect(parsed[:endpoint]).to eq("fieldName")
      expect(parsed[:legacy]).to be true
      expect(parsed[:keys]).to be_empty
    end

    it "parses two segments as legacy ref" do
      parsed = described_class.parse_trevl_ref("endpoint.field")
      expect(parsed[:endpoint]).to eq("endpoint")
      expect(parsed[:legacy]).to be true
      expect(parsed[:keys]).to eq(["field"])
    end
  end

  describe "#render — injected data sources" do
    let(:component) do
      {
        "id" => "c",
        "type" => "chart",
        "api" => "injected",
        "highchartsData" => {
          "series" => [{"data" => {"x" => "$rows.data.x", "y" => "$rows.data.y"}}]
        }
      }
    end

    let(:injected_source) do
      Trevl::DataSource::Static.new(data: {"rows" => {"data" => [{"x" => "A", "y" => 1}], "meta" => {}}})
    end

    it "renders from an injected source without touching the global registry" do
      result = described_class.new(component, {}, data_sources: {"injected" => injected_source}).render

      expect(result["highchartsData"]["series"].first["data"].first["y"]).to eq(1)
      expect(Trevl::DataSource.names).not_to include("injected")
    end

    it "prefers an injected source over a registered one with the same name" do
      Trevl::DataSource.register("injected", Trevl::DataSource::Static.new(
        data: {"rows" => {"data" => [{"x" => "A", "y" => 99}], "meta" => {}}}
      ))

      result = described_class.new(component, {}, data_sources: {"injected" => injected_source}).render

      expect(result["highchartsData"]["series"].first["data"].first["y"]).to eq(1)
    end

    it "normalizes injected source names like the registry does" do
      result = described_class.new(component, {}, data_sources: {" Injected ": injected_source}).render

      expect(result["highchartsData"]["series"].first["data"].first["y"]).to eq(1)
    end

    it "instantiates a data source passed as a class" do
      source_class = Class.new(Trevl::DataSource::Base) do
        def fetch(_endpoint, _params = {}, resource: nil)
          {"data" => [{"x" => "A", "y" => 7}], "meta" => {}}
        end
      end

      result = described_class.new(component, {}, data_sources: {"injected" => source_class}).render

      expect(result["highchartsData"]["series"].first["data"].first["y"]).to eq(7)
    end

    it "falls back to the registry for names not injected" do
      Trevl::DataSource.register("injected", injected_source)

      result = described_class.new(component, {}, data_sources: {"other" => injected_source}).render

      expect(result["highchartsData"]["series"].first["data"].first["y"]).to eq(1)
    end

    it "raises DataSourceError when the name is neither injected nor registered" do
      renderer = described_class.new(component, {}, data_sources: {"other" => injected_source})

      expect { renderer.render }.to raise_error(Trevl::DataSourceError)
    end
  end

  describe "#render — inline data" do
    let(:inline_data) { {"rows" => {"data" => [{"x" => "A", "y" => 5}], "meta" => {}}} }

    let(:component) do
      {
        "id" => "c",
        "type" => "chart",
        "api" => "anything",
        "highchartsData" => {
          "series" => [{"data" => {"x" => "$rows.data.x", "y" => "$rows.data.y"}}]
        }
      }
    end

    it "answers any api name without touching the global registry" do
      result = described_class.new(component, {}, data: inline_data).render

      expect(result["highchartsData"]["series"].first["data"].first["y"]).to eq(5)
      expect(Trevl::DataSource.names).not_to include("anything")
    end

    it "serves components without an api key" do
      result = described_class.new(component.except("api"), {}, data: inline_data).render

      expect(result["highchartsData"]["series"].first["data"].first["y"]).to eq(5)
    end

    it "accepts plain row arrays per endpoint" do
      result = described_class.new(component, {}, data: {"rows" => [{"x" => "A", "y" => 6}]}).render

      expect(result["highchartsData"]["series"].first["data"].first["y"]).to eq(6)
    end

    it "yields to an explicitly injected source with the component's api name" do
      injected = Trevl::DataSource::Static.new(data: {"rows" => {"data" => [{"x" => "A", "y" => 1}], "meta" => {}}})

      result = described_class.new(component, {},
        data: inline_data, data_sources: {"anything" => injected}).render

      expect(result["highchartsData"]["series"].first["data"].first["y"]).to eq(1)
    end
  end

  describe ".coerce_fetch_payload" do
    it "wraps Array in standard structure" do
      result = described_class.coerce_fetch_payload([{"a" => 1}])
      expect(result).to eq({"data" => [{"a" => 1}], "meta" => {}})
    end

    it "normalizes Hash with data key" do
      result = described_class.coerce_fetch_payload({"data" => [{"a" => 1}], "meta" => {"n" => 5}})
      expect(result["data"]).to eq([{"a" => 1}])
      expect(result["meta"]).to eq({"n" => 5})
    end

    it "returns empty for nil" do
      result = described_class.coerce_fetch_payload(nil)
      expect(result).to eq({"data" => [], "meta" => {}})
    end
  end

  private

  def render_component(hash)
    described_class.new(hash).render
  end
end
