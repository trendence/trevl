# frozen_string_literal: true

require "execjs"

module Trevl
  class Renderer
    attr_reader :component, :query_params, :raw_data, :warnings

    def initialize(component_hash, query_params = {})
      @component = component_hash
      @query_params = query_params || {}
      @raw_data = {}
      @warnings = []
    end

    def render
      return render_text if component["type"] == "text"
      return render_filter if component["type"] == "filter"
      return render_table if component["type"] == "table" && has_api?
      return render_score if component["type"] == "score"
      return nil unless component["type"] == "chart"
      return nil unless has_api?

      render_chart
    end

    # Parse $resource.endpoint.scope.field or $endpoint.scope.field reference syntax.
    #
    # Examples:
    #   $salary.data.q50          → endpoint=salary, scope=data, keys=[q50]
    #   $salary.meta.total        → endpoint=salary, scope=meta, keys=[total]
    #   $surveys.dist.data.share  → resource=surveys, endpoint=dist, scope=data, keys=[share]
    #   $name                     → endpoint=name, legacy=true
    #   $salary.q50               → endpoint=salary, legacy=true, keys=[q50]
    #
    # A resource qualifier is detected when there are 4+ segments and the 3rd is "data" or "meta".
    def self.parse_trevl_ref(ref_without_dollar)
      parts = ref_without_dollar.to_s.split(".")
      resource = nil

      # 4+ segments with scope at position 3: resource.endpoint.scope.field
      if parts.length >= 4 && %w[data meta].include?(parts[2])
        resource = parts.shift
      end

      endpoint = parts[0].to_s
      return {resource: resource, endpoint: endpoint, scope: :data, keys: [], legacy: true} if parts.length < 2

      case parts[1]
      when "data"
        {resource: resource, endpoint: endpoint, scope: :data, keys: parts[2..] || [], legacy: false}
      when "meta"
        {resource: resource, endpoint: endpoint, scope: :meta, keys: parts[2..] || [], legacy: false}
      else
        {resource: resource, endpoint: endpoint, scope: :data, keys: [parts.last], legacy: true}
      end
    end

    def self.coerce_fetch_payload(result)
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

    def self.deep_dig_indifferent(obj, keys)
      return obj if keys.nil? || keys.empty?
      keys.reduce(obj) do |acc, key|
        return nil if acc.nil?
        next nil unless acc.is_a?(Hash)
        acc[key.to_s] || acc[key.to_sym]
      end
    end

    private

    def has_api?
      api_name = component["api"]
      !api_name.nil? && !api_name.to_s.strip.empty?
    end

    def coerce_fetch_payload(result)
      self.class.coerce_fetch_payload(result)
    end

    def parse_trevl_ref(ref)
      self.class.parse_trevl_ref(ref)
    end

    def deep_dig_indifferent(obj, keys)
      self.class.deep_dig_indifferent(obj, keys)
    end

    def ref_key(parsed)
      [parsed[:resource], parsed[:endpoint]].compact.join("/")
    end

    def ref_key_for_string(ref)
      ref_key(parse_trevl_ref(ref))
    end

    def fetch_data(endpoint, params = {}, resource: nil)
      data_source.fetch(endpoint, params, resource: resource)
    end

    def data_source
      @data_source ||= DataSource.for(component["api"])
    end

    def merge_api_params
      api_params = component["api_parameters"] || component["api-parameters"] || {}
      api_params = CoreExt::Hash.deep_stringify_keys(api_params) if api_params.is_a?(Hash)
      api_params = resolve_placeholders(api_params)

      overrides = query_params["param_override"] || query_params[:param_override]
      if overrides.is_a?(Hash)
        overrides = CoreExt::Hash.deep_stringify_keys(overrides)
        api_params = CoreExt::Hash.deep_merge(api_params, overrides)
      end

      api_params
    end

    def resolve_placeholders(params)
      params.each_with_object({}) do |(key, value), result|
        if value.is_a?(String) && value.start_with?("$")
          param_key = value.delete_prefix("$")
          raw = query_params[param_key] || query_params[param_key.to_sym]
          resolved = raw.is_a?(Array) ? raw.first : raw
          result[key] = resolved unless resolved.nil?
        elsif value.is_a?(Hash)
          resolved = resolve_placeholders(value)
          result[key] = resolved unless resolved.empty?
        else
          result[key] = value
        end
      end
    end

    # --- Chart rendering ---

    def render_chart
      references = extract_references(component["highchartsData"])
      parsed_refs = references.map { |ref| parse_trevl_ref(ref) }
      ref_keys = parsed_refs.map { |p| ref_key(p) }.uniq

      payload_by_ref_key = {}
      request_params = merge_api_params
      ref_keys.each do |key|
        parsed = parsed_refs.find { |p| ref_key(p) == key }
        payload_by_ref_key[key] = coerce_fetch_payload(
          fetch_data(parsed[:endpoint], request_params, resource: parsed[:resource])
        )
        warn_no_data(key) if payload_by_ref_key[key]["data"].empty?
      end

      @raw_data = payload_by_ref_key.transform_values { |p| CoreExt::Hash.deep_dup(p) }

      rows_by_ref_key = payload_by_ref_key.transform_values { |p| p["data"] }
      counts_before = rows_by_ref_key.transform_values(&:length)
      rows_by_ref_key = apply_computed_fields(rows_by_ref_key, payload_by_ref_key)
      rows_by_ref_key = apply_postprocess(rows_by_ref_key)
      rows_by_ref_key.each do |key, rows|
        warn_postprocess_emptied(key, counts_before[key]) if rows.empty? && counts_before[key].to_i > 0
      end

      highcharts = build_highcharts(rows_by_ref_key, payload_by_ref_key)

      result = {
        "id" => component["id"],
        "type" => "chart",
        "highchartsData" => highcharts,
        "display" => component["display"]
      }.compact
      result["warnings"] = @warnings if @warnings.any?
      result
    end

    # --- Score rendering ---

    def render_score
      return nil unless has_api?

      display = component["display"] || {}
      references = extract_references(display)
      parsed_refs = references.map { |ref| parse_trevl_ref(ref) }

      request_params = merge_api_params
      payload_by_ref_key = {}
      parsed_refs.map { |p| ref_key(p) }.uniq.each do |key|
        parsed = parsed_refs.find { |p| ref_key(p) == key }
        payload_by_ref_key[key] = coerce_fetch_payload(
          fetch_data(parsed[:endpoint], request_params, resource: parsed[:resource])
        )
      end

      rows_by_ref_key = payload_by_ref_key.transform_values { |p| p["data"] }
      rows_by_ref_key = apply_computed_fields(rows_by_ref_key, payload_by_ref_key)

      resolved_display = resolve_template_refs(display, payload_by_ref_key, rows_by_ref_key)

      result = {
        "id" => component["id"],
        "type" => "score",
        "display" => resolved_display
      }.compact
      result["warnings"] = @warnings if @warnings.any?
      result
    end

    # --- Table rendering ---

    def render_table
      return nil unless component["tableData"]

      table_def = component["tableData"]
      column_defs = Array(table_def["columns"])

      references = extract_references(column_defs)
      parsed_refs = references.map { |ref| parse_trevl_ref(ref) }
      rk_list = parsed_refs.map { |p| ref_key(p) }.uniq.compact

      request_params = merge_api_params
      payload_by_ref_key = {}
      parsed_refs.uniq { |p| ref_key(p) }.each do |parsed|
        rk = ref_key(parsed)
        payload_by_ref_key[rk] = coerce_fetch_payload(
          fetch_data(parsed[:endpoint], request_params, resource: parsed[:resource])
        )
      end

      rows_by_ref_key = payload_by_ref_key.transform_values { |p| p["data"] }
      rows_by_ref_key = apply_computed_fields(rows_by_ref_key, payload_by_ref_key)
      rows_by_ref_key = apply_postprocess(rows_by_ref_key)

      primary_rk = rk_list.first
      rows = primary_rk ? (rows_by_ref_key[primary_rk] || []) : []

      output_rows = rows.map do |row|
        column_defs.each_with_object({}) do |col_def, output_row|
          identifier = col_def["identifier"]
          next if identifier.nil? || identifier.empty?

          value_ref = col_def["value"]
          if value_ref.is_a?(String) && value_ref.start_with?("$")
            parsed = parse_trevl_ref(value_ref.delete_prefix("$"))
            rk = ref_key(parsed)
            ep_meta = (payload_by_ref_key[rk] || {})["meta"] || {}
            row_keys = (parsed[:legacy] && parsed[:keys].empty?) ? [parsed[:endpoint]] : parsed[:keys]
            output_row[identifier] = (parsed[:scope] == :meta) ? deep_dig_indifferent(ep_meta, parsed[:keys]) : deep_dig_indifferent(row, row_keys)
          else
            output_row[identifier] = value_ref
          end
        end
      end

      {"id" => component["id"], "type" => "table", "tableData" => {"headers" => table_def["headers"], "columns" => output_rows}.compact}
    end

    # --- Filter rendering ---

    def render_filter
      return nil unless has_api?

      filter_defs = Array(component["filters"])
      return nil if filter_defs.empty?

      request_params = merge_api_params
      rows_cache = {}

      resolved_filters = filter_defs.map do |filter_def|
        options_template = filter_def["options"] || {}
        references = extract_references(options_template)
        parsed = references.map { |ref| parse_trevl_ref(ref) }.first
        rk = parsed ? ref_key(parsed) : nil

        payload = if parsed
          rows_cache[rk] ||= coerce_fetch_payload(fetch_data(parsed[:endpoint], request_params, resource: parsed[:resource]))
        else
          {"data" => [], "meta" => {}}
        end
        rows = payload["data"]

        options = rows.map do |row|
          options_template.transform_values do |tmpl|
            resolve_filter_value(tmpl, row, payload, rk)
          end
        end

        filter_def.merge("options" => options).except("queries")
      end

      {"id" => component["id"], "type" => "filter", "filters" => resolved_filters}
    end

    # --- Text rendering ---

    def render_text
      {"id" => component["id"], "type" => "text", "text" => component["text"],
       "subheader" => component["subheader"], "body" => component["body"]}.compact
    end

    # --- Shared helpers ---

    def extract_references(obj)
      refs = []
      case obj
      when Hash then obj.each_value { |v| refs.concat(extract_references(v)) }
      when Array then obj.each { |v| refs.concat(extract_references(v)) }
      when String then refs << obj.delete_prefix("$") if obj.start_with?("$")
      end
      refs.uniq
    end

    def apply_computed_fields(rows_by_ref_key, payload_by_ref_key)
      computeds = Array(component["computed"])

      if component["queries"].is_a?(Array)
        existing_names = computeds.map { |c| c["name"] }.compact
        component["queries"].each do |q|
          Array(q["computed"]).each do |c|
            computeds << c unless existing_names.include?(c["name"])
          end
        end
      end

      return rows_by_ref_key unless computeds.any?

      rows_by_ref_key.each do |rk, rows|
        rows.each do |row|
          computeds.each do |computed|
            args = computed["arguments"] || {}
            arg_names = []
            arg_values = []

            args.each do |name, ref|
              arg_names << name
              if ref.is_a?(String) && ref.start_with?("$")
                p = parse_trevl_ref(ref.delete_prefix("$"))
                p_key = ref_key(p)
                ep_meta = (payload_by_ref_key[p_key] || {})["meta"] || {}
                val = if p[:scope] == :meta
                  deep_dig_indifferent(ep_meta, p[:keys])
                elsif p_key == rk
                  deep_dig_indifferent(row, p[:keys])
                else
                  first = payload_by_ref_key[p_key]&.dig("data")&.first
                  deep_dig_indifferent(first, p[:keys])
                end
                arg_values << val
              else
                arg_values << ref
              end
            end

            js = "(function(#{arg_names.join(", ")}) { return #{computed["code"]} })(#{arg_values.map(&:to_json).join(", ")})"
            row[computed["name"]] = ExecJS.eval(js)
          end
        end
      end

      rows_by_ref_key
    end

    def apply_postprocess(rows_by_ref_key)
      code = component["postprocess"]
      return rows_by_ref_key unless code.is_a?(String) && !code.strip.empty?

      rows_by_ref_key.each do |rk, rows|
        js = "(function() { var $result = #{rows.to_json}; #{code.strip.chomp(";")}; return $result; })()"
        begin
          result = ExecJS.eval(js)
          if result.is_a?(Array)
            rows_by_ref_key[rk] = result
          else
            @warnings << "Postprocess for '#{component["id"]}' returned #{result.class} instead of Array"
            Trevl.logger.warn("[Trevl::Renderer] Postprocess returned non-Array for '#{component["id"]}'")
          end
        rescue ExecJS::Error => e
          raise RenderError, "Postprocess JavaScript error for '#{component["id"]}': #{e.message}"
        end
      end

      rows_by_ref_key
    end

    def build_highcharts(rows_by_ref_key, payload_by_ref_key)
      template = CoreExt::Hash.deep_dup(component["highchartsData"])
      series_templates = template.delete("series") || []

      all_categories = nil

      built_series = series_templates.map do |s_tmpl|
        data_template = s_tmpl.delete("data") || {}
        rk = detect_ref_key(data_template, rows_by_ref_key)
        rows = rk ? (rows_by_ref_key[rk] || []) : []
        meta = rk ? ((payload_by_ref_key[rk] || {})["meta"] || {}) : {}

        x_field_keys = extract_data_path_keys_for_categories(data_template["x"])

        data_points = rows.each_with_index.map do |row, idx|
          point = {}
          data_template.each do |key, val|
            point[key] = resolve_data_value(key, val, row, idx, meta: meta, current_ref_key: rk)
          end
          point
        end

        if x_field_keys
          all_categories = rows.map { |row| deep_dig_indifferent(row, x_field_keys) }
        end

        resolved_tmpl = resolve_series_fields(s_tmpl, rows, meta: meta)
        resolved_tmpl.merge("data" => data_points)
      end

      template["xAxis"] = inject_categories(template["xAxis"], all_categories) if all_categories
      resolved_template = resolve_template_refs(template, payload_by_ref_key)
      resolved_template.merge("series" => built_series)
    end

    def resolve_template_refs(obj, payload_by_ref_key, rows_override = nil)
      case obj
      when Hash then obj.transform_values { |v| resolve_template_refs(v, payload_by_ref_key, rows_override) }
      when Array then obj.map { |v| resolve_template_refs(v, payload_by_ref_key, rows_override) }
      when String
        return obj unless obj.start_with?("$")
        parsed = parse_trevl_ref(obj.delete_prefix("$"))
        rk = ref_key(parsed)
        payload = payload_by_ref_key[rk] || {}
        if parsed[:scope] == :meta
          deep_dig_indifferent(payload["meta"] || {}, parsed[:keys]) || obj
        else
          rows = rows_override&.dig(rk) || payload["data"] || []
          row = rows.first
          deep_dig_indifferent(row, parsed[:keys]) || obj
        end
      else obj
      end
    end

    def resolve_data_value(key, val, row, index, meta:, current_ref_key:)
      if val.is_a?(Hash)
        return val.transform_values { |v| resolve_data_value(nil, v, row, index, meta: meta, current_ref_key: current_ref_key) }
      end
      return val unless val.is_a?(String) && val.start_with?("$")

      parsed = parse_trevl_ref(val.delete_prefix("$"))
      rk = ref_key(parsed)
      if rk != current_ref_key
        return index if key == "x"
        return row[parsed[:endpoint]] || row[parsed[:endpoint].to_sym] if parsed[:legacy] && parsed[:keys].empty?
        return nil
      end

      if key == "x"
        index
      elsif parsed[:scope] == :meta
        deep_dig_indifferent(meta, parsed[:keys])
      else
        deep_dig_indifferent(row, parsed[:keys])
      end
    end

    def resolve_series_fields(s_tmpl, rows, meta:)
      s_tmpl.each_with_object({}) do |(key, val), result|
        if val.is_a?(String) && val.start_with?("$")
          parsed = parse_trevl_ref(val.delete_prefix("$"))
          row_keys = (parsed[:legacy] && parsed[:keys].empty?) ? [parsed[:endpoint]] : parsed[:keys]
          resolved = if parsed[:scope] == :meta
            deep_dig_indifferent(meta, parsed[:keys])
          else
            deep_dig_indifferent(rows.first, row_keys)
          end
          result[key] = resolved.nil? ? val : resolved
        else
          result[key] = val
        end
      end
    end

    def detect_ref_key(data_template, rows_by_ref_key = {})
      first_candidate = nil
      data_template.each_value do |val|
        next unless val.is_a?(String) && val.start_with?("$")
        rk = ref_key_for_string(val.delete_prefix("$"))
        return rk if rows_by_ref_key.key?(rk)
        first_candidate ||= rk
      end
      first_candidate
    end

    def extract_data_path_keys_for_categories(x_ref)
      return nil unless x_ref.is_a?(String) && x_ref.start_with?("$")
      p = parse_trevl_ref(x_ref.delete_prefix("$"))
      return nil if p[:scope] == :meta
      return [p[:endpoint]] if p[:legacy] && p[:keys].empty?
      p[:keys].empty? ? nil : p[:keys]
    end

    def inject_categories(x_axis, categories)
      case x_axis
      when Array then x_axis.map { |axis| axis.merge("categories" => categories) }
      when Hash then [x_axis.merge("categories" => categories)]
      else [{"categories" => categories}]
      end
    end

    def resolve_filter_value(tmpl, row, payload, rk)
      return tmpl unless tmpl.is_a?(String)

      tmpl.gsub(/\$([a-zA-Z0-9_-]+)\.data\.([a-zA-Z0-9_.]+)/) do
        path = Regexp.last_match(2).split(".")
        deep_dig_indifferent(row, path) || Regexp.last_match(0)
      end.gsub(/\$([a-zA-Z0-9_-]+)\.([a-zA-Z0-9_]+)/) do
        field = Regexp.last_match(2)
        next Regexp.last_match(0) if %w[data meta].include?(field)
        (row[field] || row[field.to_sym]) || Regexp.last_match(0)
      end
    end

    def warn_no_data(rk)
      msg = "No data returned for '#{rk}'"
      @warnings << msg
      Trevl.logger.warn("[Trevl::Renderer] #{msg} (component: #{component["id"]})")
    end

    def warn_postprocess_emptied(rk, count_before)
      msg = "Postprocess removed all #{count_before} rows for '#{rk}'"
      @warnings << msg
      Trevl.logger.warn("[Trevl::Renderer] #{msg} (component: #{component["id"]})")
    end
  end
end
