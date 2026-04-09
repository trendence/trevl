# frozen_string_literal: true

RSpec.describe Trevl::HtmlRenderer do
  before do
    Trevl::DataSource.register("static", Trevl::DataSource::Static.new(
      data: {
        "salary" => {
          "data" => [
            {"label" => "Junior", "value" => 42000},
            {"label" => "Senior", "value" => 78000}
          ],
          "meta" => {"total" => 2}
        }
      }
    ))
  end

  let(:chart_yaml) do
    <<~YAML
      components:
      - id: test_chart
        type: chart
        api: static
        highchartsData:
          chart:
            type: bar
          title:
            text: Test Chart
          series:
          - name: Salary
            data:
              x: "$salary.data.label"
              y: "$salary.data.value"
    YAML
  end

  let(:score_yaml) do
    <<~YAML
      components:
      - id: test_score
        type: score
        api: static
        display:
          value: "$salary.meta.total"
          unit: " results"
          header:
            title: Total
    YAML
  end

  describe "#render" do
    it "produces a complete standalone HTML document" do
      html = described_class.new.render(chart_yaml)

      expect(html).to include("<!DOCTYPE html>")
      expect(html).to include("<html>")
      expect(html).to include("</html>")
      expect(html).to include("Highcharts.chart")
    end

    it "embeds Highcharts JS inline" do
      html = described_class.new.render(chart_yaml)

      expect(html).to include("<script>")
      expect(html).to include("Highcharts")
      expect(html).not_to include("code.highcharts.com")
    end

    it "includes chart data from the rendered component" do
      html = described_class.new.render(chart_yaml)

      expect(html).to include("Test Chart")
      expect(html).to include("42000")
      expect(html).to include("78000")
    end

    it "renders score components" do
      html = described_class.new.render(score_yaml)

      expect(html).to include("Total")
      expect(html).to include("2 results")
    end

    it "renders multiple components in one document" do
      yaml = <<~YAML
        components:
        - id: chart1
          type: chart
          api: static
          highchartsData:
            series:
            - data:
                y: "$salary.data.value"
        - id: chart2
          type: chart
          api: static
          highchartsData:
            series:
            - data:
                y: "$salary.data.value"
      YAML

      html = described_class.new.render(yaml)

      expect(html).to include("trevl_chart_0")
      expect(html).to include("trevl_chart_1")
    end

    it "respects custom dimensions" do
      html = described_class.new(width: 1200, height: 600).render(chart_yaml)

      expect(html).to include("1200px")
      expect(html).to include("600px")
    end

    it "uses default dimensions" do
      html = described_class.new.render(chart_yaml)

      expect(html).to include("800px")
      expect(html).to include("400px")
    end
  end

  describe "#render_component" do
    it "renders a single chart result to HTML" do
      results = Trevl.render(chart_yaml)
      html = described_class.new.render_component(results.first)

      expect(html).to include("<!DOCTYPE html>")
      expect(html).to include("Highcharts.chart")
    end

    it "renders a single score result to HTML" do
      results = Trevl.render(score_yaml)
      html = described_class.new.render_component(results.first)

      expect(html).to include("Total")
    end

    it "returns empty string for unsupported types" do
      html = described_class.new.render_component({"type" => "text", "text" => "hello"})
      expect(html).to eq("")
    end
  end
end

RSpec.describe "Trevl.render_to_html" do
  before do
    Trevl::DataSource.register("static", Trevl::DataSource::Static.new(
      data: {
        "data" => {
          "data" => [{"x" => "A", "y" => 10}],
          "meta" => {}
        }
      }
    ))
  end

  it "is a convenience method on the Trevl module" do
    html = Trevl.render_to_html(<<~YAML)
      components:
      - id: c1
        type: chart
        api: static
        highchartsData:
          series:
          - data:
              y: "$data.data.y"
    YAML

    expect(html).to include("<!DOCTYPE html>")
    expect(html).to include("Highcharts.chart")
  end

  it "accepts width and height" do
    html = Trevl.render_to_html(<<~YAML, width: 1000, height: 500)
      components:
      - id: c1
        type: chart
        api: static
        highchartsData:
          series:
          - data:
              y: "$data.data.y"
    YAML

    expect(html).to include("1000px")
    expect(html).to include("500px")
  end
end
