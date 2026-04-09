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

      def all
        registry.map do |name, source|
          obj = source.is_a?(Class) ? source : source.class
          {name: name, type: obj.name&.split("::")&.last || obj.to_s, source: source}
        end
      end

      def names
        registry.keys
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
