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
require_relative "trevl/validator"

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

    def validate(yaml_string)
      Validator.validate(yaml_string)
    end

    def render(yaml_string, params: {})
      processor = parse(yaml_string)
      components = processor.components || []
      components.filter_map do |component|
        Renderer.new(component, params).render
      end
    end

    GEM_ROOT = File.expand_path("..", __dir__)

    def schema_reference
      @schema_reference ||= File.read(File.join(GEM_ROOT, "llms.txt"))
    end

    def examples
      @examples ||= load_examples
    end

    def reset!
      @configuration = Configuration.new
      @schema_reference = nil
      @examples = nil
    end

    private

    def load_examples
      dir = File.join(GEM_ROOT, "examples")
      return [] unless File.directory?(dir)

      Dir.glob(File.join(dir, "*.yml")).sort.map do |path|
        name = File.basename(path, ".yml")
        content = File.read(path)
        comment_lines = content.lines.take_while { |l| l.start_with?("#") }
        description = comment_lines.map { |l| l.sub(/^#\s?/, "").chomp }.join(" ").strip

        {name: name, description: description, yaml: content.sub(/\A(#[^\n]*\n)+/, "")}
      end
    end
  end
end
