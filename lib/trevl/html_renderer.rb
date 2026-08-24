# frozen_string_literal: true

module Trevl
  # Renders TREVL YAML to an HTML page that draws its charts with Highcharts.
  # Highcharts itself is loaded from the CDN by default; configure
  # `highcharts_path` to inline a local copy and get a self-contained file
  # that works offline.
  #
  #   html = Trevl.render_to_html(yaml_string)
  #   File.write("chart.html", html)
  #
  # For screenshots, open the HTML file with any headless browser:
  #   - Grover gem: Grover.new(html).to_png
  #   - Ferrum: browser.goto("file:///tmp/chart.html"); browser.screenshot
  #   - Playwright MCP: browser_navigate + browser_take_screenshot
  #   - CLI: npx puppeteer screenshot chart.html
  #
  class HtmlRenderer
    def initialize(width: 800, height: 400, background: "#ffffff")
      @width = width
      @height = height
      @background = background
    end

    # Renders TREVL YAML to a standalone HTML string.
    # Returns a complete HTML document with all charts embedded.
    def render(yaml_string, params: {}, data: nil, data_sources: {})
      results = Trevl.render(yaml_string, params: params, data: data, data_sources: data_sources)
      charts = results.select { |r| r["type"] == "chart" && r["highchartsData"] }
      scores = results.select { |r| r["type"] == "score" && r["display"] }

      build_html(charts, scores)
    end

    # Renders a single pre-rendered component hash to HTML.
    def render_component(result)
      case result["type"]
      when "chart" then build_html([result], [])
      when "score" then build_html([], [result])
      else ""
      end
    end

    private

    def build_html(charts, scores)
      <<~HTML
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="utf-8">
          <style>
            body { margin: 0; padding: 20px; background: #{@background}; font-family: -apple-system, BlinkMacSystemFont, sans-serif; }
            .trevl-chart { width: #{@width}px; height: #{@height}px; margin: 0 auto 20px; }
            .trevl-score { text-align: center; padding: 20px; margin: 0 auto 20px; }
            .trevl-score-title { font-size: 14px; color: #6b7280; margin-bottom: 8px; }
            .trevl-score-value { font-size: 48px; font-weight: 700; color: #1f2937; }
          </style>
          #{HighchartsAsset.script_tags}
        </head>
        <body>
          #{scores.map { |s| score_html(s) }.join("\n")}
          #{charts.each_with_index.map { |c, i| chart_html(c, i) }.join("\n")}
        </body>
        </html>
      HTML
    end

    def chart_html(result, index)
      container_id = "trevl_chart_#{index}"
      <<~HTML
        <div id="#{container_id}" class="trevl-chart"></div>
        <script>Highcharts.chart('#{container_id}', #{result["highchartsData"].to_json});</script>
      HTML
    end

    def score_html(result)
      display = result["display"] || {}
      value = display["value"]
      unit = display["unit"] || ""
      title = display.dig("header", "title") || ""

      <<~HTML
        <div class="trevl-score">
          <div class="trevl-score-title">#{title}</div>
          <div class="trevl-score-value">#{value}#{unit}</div>
        </div>
      HTML
    end
  end
end
