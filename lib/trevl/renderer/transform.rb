# frozen_string_literal: true

require "execjs"

module Trevl
  class Renderer
    # Applies computed fields and postprocess transformations to data rows.
    #
    #   transform = Transform.new(ref_parser)
    #   transform.apply_computed_fields(rows, payloads, component)
    #
    class Transform
      def initialize(ref_parser)
        @refs = ref_parser
      end

      # Applies computed fields (per-row JavaScript expressions) to all rows.
      def apply_computed_fields(rows_by_ref_key, payload_by_ref_key, component)
        computeds = collect_computed_fields(component)
        return rows_by_ref_key unless computeds.any?

        rows_by_ref_key.each do |rk, rows|
          rows.each do |row|
            computeds.each do |computed|
              arg_names, arg_values = resolve_arguments(computed, row, rk, payload_by_ref_key)
              js = "(function(#{arg_names.join(", ")}) { return #{computed["code"]} })(#{arg_values.map(&:to_json).join(", ")})"
              row[computed["name"]] = ExecJS.eval(js)
            end
          end
        end

        rows_by_ref_key
      end

      # Applies postprocess JavaScript to the full dataset.
      def apply_postprocess(rows_by_ref_key, component, warnings)
        code = component["postprocess"]
        return rows_by_ref_key unless code.is_a?(String) && !code.strip.empty?

        rows_by_ref_key.each do |rk, rows|
          js = "(function() { var $result = #{rows.to_json}; #{code.strip.chomp(";")}; return $result; })()"
          begin
            result = ExecJS.eval(js)
            if result.is_a?(Array)
              rows_by_ref_key[rk] = result
            else
              warnings << "Postprocess for '#{component["id"]}' returned #{result.class} instead of Array"
              Trevl.logger.warn("[Trevl::Renderer] Postprocess returned non-Array for '#{component["id"]}'")
            end
          rescue ExecJS::Error => e
            raise RenderError, "Postprocess JavaScript error for '#{component["id"]}': #{e.message}"
          end
        end

        rows_by_ref_key
      end

      private

      def collect_computed_fields(component)
        computeds = Array(component["computed"])

        if component["queries"].is_a?(Array)
          existing_names = computeds.map { |c| c["name"] }.compact
          component["queries"].each do |q|
            Array(q["computed"]).each do |c|
              computeds << c unless existing_names.include?(c["name"])
            end
          end
        end

        computeds
      end

      def resolve_arguments(computed, row, rk, payload_by_ref_key)
        args = computed["arguments"] || {}
        arg_names = []
        arg_values = []

        args.each do |name, ref|
          arg_names << name
          if ref.is_a?(String) && ref.start_with?("$")
            p = @refs.parse(ref.delete_prefix("$"))
            p_key = @refs.ref_key(p)
            ep_meta = (payload_by_ref_key[p_key] || {})["meta"] || {}
            val = if p[:scope] == :meta
              @refs.dig(ep_meta, p[:keys])
            elsif p_key == rk
              @refs.dig(row, p[:keys])
            else
              first = payload_by_ref_key[p_key]&.dig("data")&.first
              @refs.dig(first, p[:keys])
            end
            arg_values << val
          else
            arg_values << ref
          end
        end

        [arg_names, arg_values]
      end
    end
  end
end
