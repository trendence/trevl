# frozen_string_literal: true

module Trevl
  class Configuration
    attr_accessor :logger
    attr_writer :template_store

    def initialize
      @logger = Logger.new($stderr, level: Logger::WARN)
      @template_store = nil
    end

    def template_store
      @template_store ||= TemplateStore.new
    end
  end
end
