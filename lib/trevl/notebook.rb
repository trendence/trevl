# frozen_string_literal: true

require_relative "notebook/display"

module Trevl
  class Notebook
    attr_reader :display

    def initialize
      @display = Display.new
    end

    # Render a TREVL YAML string as an interactive Highcharts chart in iRuby.
    # Optionally pass static data to avoid API calls — inline data answers any
    # api name and components without one (Trevl.render data: semantics).
    def chart(yaml_string, params: {}, data: nil, height: 400)
      results = Trevl.render(yaml_string, params: params, data: data)
      results.each do |result|
        next unless result["type"] == "chart" && result["highchartsData"]
        @display.render_chart(result["highchartsData"], height: height)
      end
      nil
    end

    # Render a score component inline
    def score(yaml_string, params: {}, data: nil)
      results = Trevl.render(yaml_string, params: params, data: data)
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
  end
end
