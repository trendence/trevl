# frozen_string_literal: true

require "yaml"
require "json"
require "logger"
require "securerandom"

require_relative "trevl/version"
require_relative "trevl/errors"
require_relative "trevl/configuration"
require_relative "trevl/core_ext/hash"
require_relative "trevl/template_store"
require_relative "trevl/data_source"
require_relative "trevl/data_source/base"
require_relative "trevl/data_source/static"
require_relative "trevl/data_source/api"
require_relative "trevl/data_source/cube"
require_relative "trevl/auth/bearer_token"
require_relative "trevl/processor"
require_relative "trevl/renderer"

module Trevl
  class << self
    def configure
      yield(configuration)
    end

    def configuration
      @configuration ||= Configuration.new
    end

    def logger
      configuration.logger
    end

    def template_store
      configuration.template_store
    end

    def parse(yaml_string)
      Processor.new(yaml_string)
    end

    def render(yaml_string, params: {})
      processor = parse(yaml_string)
      components = processor.components || []
      components.filter_map do |component|
        Renderer.new(component, params).render
      end
    end

    def reset!
      @configuration = Configuration.new
    end
  end
end
