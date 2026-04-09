# frozen_string_literal: true

module Trevl
  module DataSource
    class Base
      def fetch(endpoint, params = {}, resource: nil)
        raise NotImplementedError, "#{self.class}#fetch must be implemented"
      end

      # Returns the field names available for an endpoint by fetching a sample row.
      # Override in subclasses for more efficient discovery (e.g. schema endpoints).
      def field_names(endpoint, params = {}, resource: nil)
        result = fetch(endpoint, params, resource: resource)
        row = Array(result["data"]).first
        row.is_a?(Hash) ? row.keys : []
      end
    end
  end
end
