# frozen_string_literal: true

module Trevl
  module DataSource
    class << self
      def register(name, source)
        registry[name.to_s.strip.downcase] = source
      end

      def for(name, **)
        key = name.to_s.strip.downcase
        source = registry[key]
        raise DataSourceError, "No data source registered for '#{name}'. Available: #{registry.keys.join(", ")}." unless source

        source.is_a?(Class) ? source.new(**) : source
      end

      def registry
        @registry ||= {}
      end

      def reset!
        @registry = {}
      end
    end
  end
end
