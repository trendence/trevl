# frozen_string_literal: true

module Trevl
  module CoreExt
    module Hash
      def self.deep_dup(hash)
        hash.each_with_object({}) do |(key, value), result|
          result[key] = case value
          when ::Hash then deep_dup(value)
          when ::Array then value.map { |v| v.is_a?(::Hash) ? deep_dup(v) : v }
          else value
          end
        end
      end

      def self.deep_stringify_keys(hash)
        hash.each_with_object({}) do |(key, value), result|
          result[key.to_s] = case value
          when ::Hash then deep_stringify_keys(value)
          when ::Array then value.map { |v| v.is_a?(::Hash) ? deep_stringify_keys(v) : v }
          else value
          end
        end
      end

      def self.deep_merge(base, override)
        base.merge(override) do |_key, base_val, override_val|
          if base_val.is_a?(::Hash) && override_val.is_a?(::Hash)
            deep_merge(base_val, override_val)
          else
            override_val
          end
        end
      end
    end
  end
end
