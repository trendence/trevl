# frozen_string_literal: true

require_relative "notebook/display"

module Trevl
  class Notebook
    attr_reader :display

    def initialize
      @display = Display.new
    end

    # Render a TREVL YAML string as an interactive Highcharts chart in iRuby.
    # Optionally pass static data to avoid API calls.
    def chart(yaml_string, params: {}, data: nil, height: 400)
      if data
        DataSource.register("static", DataSource::Static.new(data: data))
        yaml_string = inject_api(yaml_string, "static")
      end

      results = Trevl.render(yaml_string, params: params)
      results.each do |result|
        next unless result["type"] == "chart" && result["highchartsData"]
        @display.render_chart(result["highchartsData"], height: height)
      end
      nil
    end

    # Render a score component inline
    def score(yaml_string, params: {}, data: nil)
      if data
        DataSource.register("static", DataSource::Static.new(data: data))
        yaml_string = inject_api(yaml_string, "static")
      end

      results = Trevl.render(yaml_string, params: params)
      results.each do |result|
        next unless result["type"] == "score"
        @display.render_score(result["display"] || result)
      end
      nil
    end

    # Fetch raw data from a registered data source
    def fetch(source_name, endpoint, params = {}, resource: nil)
      source = DataSource.for(source_name)
      source.fetch(endpoint, params, resource: resource)
    end

    private

    def inject_api(yaml_string, api_name)
      parsed = YAML.safe_load(yaml_string, permitted_classes: [Hash, Symbol], aliases: true)
      components = parsed.is_a?(Array) ? parsed : (parsed["components"] || [parsed])
      components.each { |c| c["api"] ||= api_name if c.is_a?(Hash) }
      (parsed.is_a?(Array) ? components : parsed).to_yaml
    end
  end
end
