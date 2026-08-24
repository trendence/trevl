# frozen_string_literal: true

module Trevl
  class Configuration
    # Highcharts is commercially licensed and not bundled with this gem, so it
    # is loaded from the CDN unless a local copy is configured.
    HIGHCHARTS_CDN_URL = "https://code.highcharts.com/11.4.0/highcharts.js"

    attr_accessor :logger, :highcharts_url, :highcharts_path, :highcharts_modules
    attr_writer :template_store

    def initialize
      @logger = Logger.new($stderr, level: Logger::WARN)
      @template_store = nil
      @highcharts_url = HIGHCHARTS_CDN_URL
      @highcharts_path = nil
      @highcharts_modules = []
    end

    def template_store
      @template_store ||= TemplateStore.new
    end
  end
end
