# frozen_string_literal: true

module Trevl
  module DataSource
    class Static < Base
      attr_reader :data

      def initialize(data: {}, **)
        super()
        @data = data
      end

      def fetch(endpoint, params = {}, resource: nil)
        key = resource ? "#{resource}/#{endpoint}" : endpoint
        result = @data[key] || @data[endpoint]

        case result
        when Array
          {"data" => result, "meta" => {}}
        when Hash
          data = result["data"] || result[:data] || []
          meta = result["meta"] || result[:meta] || {}
          {"data" => Array(data), "meta" => meta.is_a?(Hash) ? meta : {}}
        else
          {"data" => [], "meta" => {}}
        end
      end
    end
  end
end
