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

      # Returns all registered data sources as an array of hashes.
      #
      #   Trevl::DataSource.all
      #   # => [
      #   #   {name: "myapi", type: "Api", source: #<Trevl::DataSource::Api ...>},
      #   #   {name: "cube",  type: "Cube", source: #<Trevl::DataSource::Cube ...>}
      #   # ]
      def all
        registry.map do |name, source|
          type = if source.is_a?(Class)
            source.name&.split("::")&.last || source.to_s
          else
            source.class.name&.split("::")&.last || source.class.to_s
          end

          info = {name: name, type: type, source: source}
          info[:base_url] = source.base_url if source.respond_to?(:base_url)
          info[:url] = source.instance_variable_get(:@url) if source.respond_to?(:fetch) && source.instance_variable_defined?(:@url)
          info
        end
      end

      # Returns just the registered names.
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
