# frozen_string_literal: true

module Trevl
  class Renderer
    # Normalizes API responses and resolves API parameters.
    #
    #   fetcher = DataFetcher.new
    #   fetcher.coerce_payload([{x: 1}])
    #   # => {"data" => [{"x" => 1}], "meta" => {}}
    #
    class DataFetcher
      def coerce_payload(result)
        case result
        when Array
          {"data" => result, "meta" => {}}
        when Hash
          data = result["data"] || result[:data]
          meta = result["meta"] || result[:meta] || {}
          meta = {} unless meta.is_a?(Hash)
          if data.is_a?(Array)
            {"data" => data, "meta" => CoreExt::Hash.deep_stringify_keys(meta)}
          else
            {"data" => [], "meta" => CoreExt::Hash.deep_stringify_keys(meta)}
          end
        else
          {"data" => [], "meta" => {}}
        end
      end

      def merge_api_params(component, query_params)
        api_params = component["api_parameters"] || component["api-parameters"] || {}
        api_params = CoreExt::Hash.deep_stringify_keys(api_params) if api_params.is_a?(Hash)
        api_params = resolve_placeholders(api_params, query_params)

        overrides = query_params["param_override"] || query_params[:param_override]
        if overrides.is_a?(Hash)
          overrides = CoreExt::Hash.deep_stringify_keys(overrides)
          api_params = CoreExt::Hash.deep_merge(api_params, overrides)
        end

        api_params
      end

      private

      def resolve_placeholders(params, query_params)
        params.each_with_object({}) do |(key, value), result|
          if value.is_a?(String) && value.start_with?("$")
            param_key = value.delete_prefix("$")
            raw = query_params[param_key] || query_params[param_key.to_sym]
            resolved = raw.is_a?(Array) ? raw.first : raw
            result[key] = resolved unless resolved.nil?
          elsif value.is_a?(Hash)
            resolved = resolve_placeholders(value, query_params)
            result[key] = resolved unless resolved.empty?
          else
            result[key] = value
          end
        end
      end
    end
  end
end
