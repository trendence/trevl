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
require_relative "trevl/html_renderer"

module Trevl
  GEM_ROOT = File.expand_path("..", __dir__)

  class << self
    # --- Configuration ---

    def configure
      yield(configuration)
    end

    def configuration
      @configuration ||= Configuration.new
    end

    def logger = configuration.logger
    def template_store = configuration.template_store

    # --- Core API ---

    def parse(yaml_string)
      Processor.new(yaml_string)
    end

    def validate(yaml_string)
      Validator.validate(yaml_string)
    end

    # data: inline rows for this render call ({endpoint => rows}), wrapped in
    # a Static source internally; answers any api name and components without
    # one. data_sources: per-render sources ({name => instance}). Both take
    # precedence over the global DataSource registry.
    def render(yaml_string, params: {}, data: nil, data_sources: {})
      components = parse(yaml_string).components || []
      components.filter_map { |c| Renderer.new(c, params, data: data, data_sources: data_sources).render }
    end

    def render_to_html(yaml_string, params: {}, data: nil, data_sources: {}, width: 800, height: 400)
      HtmlRenderer.new(width: width, height: height)
        .render(yaml_string, params: params, data: data, data_sources: data_sources)
    end

    # --- AI tooling ---

    def schema_reference
      @schema_reference ||= File.read(File.join(GEM_ROOT, "llms.txt"))
    end

    def examples
      @examples ||= load_examples
    end

    # --- Lifecycle ---

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
