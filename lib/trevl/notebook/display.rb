# frozen_string_literal: true

module Trevl
  class Notebook
    class Display
      HIGHCHARTS_JS_PATH = File.expand_path("../../../vendor/highcharts/highcharts.js", __dir__)

      def render_chart(highcharts_data, height: 400)
        container_id = "trevl_#{SecureRandom.hex(6)}"
        highcharts_js = load_highcharts_js

        html = <<~HTML
          <div id="#{container_id}" style="width:100%;height:#{height}px;"></div>
          <script>
            if (typeof Highcharts === 'undefined') {
              #{highcharts_js}
            }
            Highcharts.chart('#{container_id}', #{highcharts_data.to_json});
          </script>
        HTML

        display_html(html)
      end

      def render_score(display_data)
        value = display_data["value"]
        unit = display_data["unit"] || ""
        header = display_data["header"] || {}
        title = header["title"] || ""

        html = <<~HTML
          <div style="text-align:center;padding:20px;font-family:sans-serif;">
            <div style="font-size:14px;color:#6b7280;margin-bottom:8px;">#{title}</div>
            <div style="font-size:48px;font-weight:700;color:#1f2937;">#{value}#{unit}</div>
          </div>
        HTML

        display_html(html)
      end

      private

      def load_highcharts_js
        if File.exist?(HIGHCHARTS_JS_PATH)
          File.read(HIGHCHARTS_JS_PATH)
        else
          Trevl.logger.warn("[Trevl::Notebook] Highcharts JS not found at #{HIGHCHARTS_JS_PATH}, falling back to CDN")
          'document.write(\'<script src="https://code.highcharts.com/highcharts.js"><\\/script>\')'
        end
      end

      def display_html(html)
        if defined?(IRuby)
          IRuby.display(html, mime: "text/html")
        else
          puts html
        end
      end
    end
  end
end
