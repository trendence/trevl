# frozen_string_literal: true

module Trevl
  # Builds the <script> tags that load Highcharts into generated HTML.
  #
  # Highcharts is commercially licensed and is therefore not shipped with this
  # gem. By default it is loaded from the official CDN. Point the configuration
  # at local copies to keep the output self-contained and usable offline:
  #
  #   Trevl.configure do |config|
  #     config.highcharts_path = Rails.root.join("vendor/highcharts/highcharts.js")
  #   end
  #
  # Using Highcharts requires a licence from Highsoft. See highcharts.com/license.
  module HighchartsAsset
    class << self
      # Core library plus any configured modules, as ready-to-embed script tags.
      def script_tags
        config = Trevl.configuration
        sources = [[config.highcharts_path, config.highcharts_url]] +
          config.highcharts_modules.map { |m| [local?(m) ? m : nil, m] }

        sources.map { |path, url| script_tag(path, url) }.join("\n")
      end

      private

      # A local file is inlined so the page works without network access;
      # anything else becomes a src reference.
      def script_tag(path, url)
        if path && File.exist?(path.to_s)
          "<script>#{File.read(path.to_s)}</script>"
        elsif path
          raise Trevl::Error, "Highcharts JS not found at #{path}"
        else
          %(<script src="#{url}"></script>)
        end
      end

      def local?(source)
        !source.to_s.match?(%r{\Ahttps?://})
      end
    end
  end
end
