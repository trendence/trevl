# frozen_string_literal: true

module Trevl
  class Notebook
    class Display
      VENDOR_DIR = File.expand_path("../../../vendor/highcharts", __dir__)

      def render_chart(highcharts_data, height: 400)
        container_id = "trevl_#{SecureRandom.hex(6)}"

        html = +""
        html << highcharts_script_tag unless @highcharts_loaded
        html << <<~HTML
          <div id="#{container_id}" style="width:100%;height:#{height}px;"></div>
          <script>
            Highcharts.chart('#{container_id}', #{highcharts_data.to_json});
          </script>
        HTML

        @highcharts_loaded = true
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

      def highcharts_script_tag
        js_path = File.join(VENDOR_DIR, "highcharts.js")
        unless File.exist?(js_path)
          raise Trevl::Error, "Highcharts JS not found at #{js_path}. Run: curl -o #{js_path} https://unpkg.com/highcharts@11.4.0/highcharts.js"
        end

        "<script>#{File.read(js_path)}</script>\n"
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
