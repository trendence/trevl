# frozen_string_literal: true

require_relative "renderer/ref_parser"
require_relative "renderer/data_fetcher"
require_relative "renderer/transform"

module Trevl
  class Renderer
    attr_reader :component, :query_params, :data_sources, :inline_source, :raw_data, :warnings

    def initialize(component_hash, query_params = {}, data_sources: {}, data: nil)
      @component = component_hash
      @query_params = query_params || {}
      @data_sources = normalize_data_sources(data_sources)
      @inline_source = data ? DataSource::Static.new(data: data) : nil
      @raw_data = {}
      @warnings = []
      @refs = RefParser.new
      @fetcher = DataFetcher.new
      @transform = Transform.new(@refs)
    end

    def render
      case component["type"]
      when "text" then render_text
      when "filter" then has_api? ? render_filter : nil
      when "table" then has_api? ? render_table : nil
      when "score" then has_api? ? render_score : nil
      when "chart" then has_api? ? render_chart : nil
      end
    end

    # Public class methods kept for backward compatibility and testing
    def self.parse_trevl_ref(ref) = RefParser.new.parse(ref)
    def self.coerce_fetch_payload(result) = DataFetcher.new.coerce_payload(result)
    def self.deep_dig_indifferent(obj, keys) = RefParser.new.dig(obj, keys)

    private

    def has_api?
      api_name = component["api"]
      return true if inline_source
      !api_name.nil? && !api_name.to_s.strip.empty?
    end

    # Resolution order per component: explicitly injected data_sources win,
    # then inline data (when given, it answers any api name and components
    # without one), then the global registry. Injected and inline sources
    # never touch shared state (thread-safe by construction).
    def data_source
      @data_source ||= data_sources[normalize_source_name(component["api"])] ||
        inline_source ||
        DataSource.for(component["api"])
    end

    def normalize_data_sources(sources)
      (sources || {}).each_with_object({}) do |(name, source), normalized|
        normalized[normalize_source_name(name)] = source.is_a?(Class) ? source.new : source
      end
    end

    def normalize_source_name(name)
      name.to_s.strip.downcase
    end

    def request_params
      @request_params ||= @fetcher.merge_api_params(component, query_params)
    end

    # --- Data pipeline ---

    def fetch_and_prepare(references_source)
      references = @refs.extract_references(references_source)
      parsed_refs = references.map { |ref| @refs.parse(ref) }
      ref_keys = parsed_refs.map { |p| @refs.ref_key(p) }.uniq

      payload_by_ref_key = {}
      ref_keys.each do |key|
        parsed = parsed_refs.find { |p| @refs.ref_key(p) == key }
        payload_by_ref_key[key] = @fetcher.coerce_payload(
          data_source.fetch(parsed[:endpoint], request_params, resource: parsed[:resource])
        )
        warn_no_data(key) if payload_by_ref_key[key]["data"].empty?
      end

      @raw_data = payload_by_ref_key.transform_values { |p| CoreExt::Hash.deep_dup(p) }
      payload_by_ref_key
    end

    def transform_rows(payload_by_ref_key)
      rows_by_ref_key = payload_by_ref_key.transform_values { |p| p["data"] }
      counts_before = rows_by_ref_key.transform_values(&:length)

      rows_by_ref_key = @transform.apply_computed_fields(rows_by_ref_key, payload_by_ref_key, component)
      rows_by_ref_key = @transform.apply_postprocess(rows_by_ref_key, component, @warnings)

      rows_by_ref_key.each do |key, rows|
        warn_postprocess_emptied(key, counts_before[key]) if rows.empty? && counts_before[key].to_i > 0
      end

      rows_by_ref_key
    end

    # --- Component renderers ---

    def render_chart
      payload_by_ref_key = fetch_and_prepare(component["highchartsData"])
      rows_by_ref_key = transform_rows(payload_by_ref_key)
      highcharts = build_highcharts(rows_by_ref_key, payload_by_ref_key)

      build_result("chart", "highchartsData" => highcharts, "display" => component["display"])
    end

    def render_score
      display = component["display"] || {}
      payload_by_ref_key = fetch_and_prepare(display)
      rows_by_ref_key = payload_by_ref_key.transform_values { |p| p["data"] }
      rows_by_ref_key = @transform.apply_computed_fields(rows_by_ref_key, payload_by_ref_key, component)
      resolved_display = resolve_refs(display, payload_by_ref_key, rows_by_ref_key)

      build_result("score", "display" => resolved_display)
    end

    def render_table
      return nil unless component["tableData"]

      table_def = component["tableData"]
      column_defs = Array(table_def["columns"])

      payload_by_ref_key = fetch_and_prepare(column_defs)
      rows_by_ref_key = transform_rows(payload_by_ref_key)

      primary_rk = payload_by_ref_key.keys.first
      rows = primary_rk ? (rows_by_ref_key[primary_rk] || []) : []

      output_rows = rows.map do |row|
        column_defs.each_with_object({}) do |col_def, output_row|
          identifier = col_def["identifier"]
          next if identifier.nil? || identifier.empty?
          output_row[identifier] = resolve_cell_value(col_def["value"], row, payload_by_ref_key)
        end
      end

      {"id" => component["id"], "type" => "table",
       "tableData" => {"headers" => table_def["headers"], "columns" => output_rows}.compact}
    end

    def render_filter
      filter_defs = Array(component["filters"])
      return nil if filter_defs.empty?

      rows_cache = {}

      resolved_filters = filter_defs.map do |filter_def|
        options_template = filter_def["options"] || {}
        references = @refs.extract_references(options_template)
        parsed = references.map { |ref| @refs.parse(ref) }.first
        rk = parsed ? @refs.ref_key(parsed) : nil

        payload = if parsed
          rows_cache[rk] ||= @fetcher.coerce_payload(
            data_source.fetch(parsed[:endpoint], request_params, resource: parsed[:resource])
          )
        else
          {"data" => [], "meta" => {}}
        end

        options = payload["data"].map do |row|
          options_template.transform_values { |tmpl| resolve_filter_value(tmpl, row) }
        end

        filter_def.merge("options" => options).except("queries")
      end

      {"id" => component["id"], "type" => "filter", "filters" => resolved_filters}
    end

    def render_text
      {"id" => component["id"], "type" => "text", "text" => component["text"],
       "subheader" => component["subheader"], "body" => component["body"]}.compact
    end

    # --- Highcharts builder ---

    def build_highcharts(rows_by_ref_key, payload_by_ref_key)
      template = CoreExt::Hash.deep_dup(component["highchartsData"])
      series_templates = template.delete("series") || []
      all_categories = nil

      built_series = series_templates.map do |s_tmpl|
        data_template = s_tmpl.delete("data") || {}
        rk = detect_ref_key(data_template, rows_by_ref_key)
        rows = rk ? (rows_by_ref_key[rk] || []) : []
        meta = rk ? ((payload_by_ref_key[rk] || {})["meta"] || {}) : {}

        x_field_keys = extract_category_keys(data_template["x"])
        data_points = build_data_points(data_template, rows, meta, rk)
        all_categories = rows.map { |row| @refs.dig(row, x_field_keys) } if x_field_keys

        resolve_series_fields(s_tmpl, rows, meta: meta).merge("data" => data_points)
      end

      template["xAxis"] = inject_categories(template["xAxis"], all_categories) if all_categories
      resolve_refs(template, payload_by_ref_key).merge("series" => built_series)
    end

    def build_data_points(data_template, rows, meta, current_ref_key)
      rows.each_with_index.map do |row, idx|
        data_template.each_with_object({}) do |(key, val), point|
          point[key] = resolve_data_value(key, val, row, idx, meta: meta, current_ref_key: current_ref_key)
        end
      end
    end

    # --- Reference resolution ---

    def resolve_refs(obj, payload_by_ref_key, rows_override = nil)
      case obj
      when Hash then obj.transform_values { |v| resolve_refs(v, payload_by_ref_key, rows_override) }
      when Array then obj.map { |v| resolve_refs(v, payload_by_ref_key, rows_override) }
      when String
        return obj unless obj.start_with?("$")
        parsed = @refs.parse(obj.delete_prefix("$"))
        rk = @refs.ref_key(parsed)
        payload = payload_by_ref_key[rk] || {}
        if parsed[:scope] == :meta
          @refs.dig(payload["meta"] || {}, parsed[:keys]) || obj
        else
          rows = rows_override&.dig(rk) || payload["data"] || []
          @refs.dig(rows.first, parsed[:keys]) || obj
        end
      else obj
      end
    end

    def resolve_data_value(key, val, row, index, meta:, current_ref_key:)
      if val.is_a?(Hash)
        return val.transform_values { |v| resolve_data_value(nil, v, row, index, meta: meta, current_ref_key: current_ref_key) }
      end
      return val unless val.is_a?(String) && val.start_with?("$")

      parsed = @refs.parse(val.delete_prefix("$"))
      rk = @refs.ref_key(parsed)

      if rk != current_ref_key
        return index if key == "x"
        return row[parsed[:endpoint]] || row[parsed[:endpoint].to_sym] if parsed[:legacy] && parsed[:keys].empty?
        return nil
      end

      return index if key == "x"
      return @refs.dig(meta, parsed[:keys]) if parsed[:scope] == :meta
      @refs.dig(row, parsed[:keys])
    end

    def resolve_series_fields(s_tmpl, rows, meta:)
      s_tmpl.each_with_object({}) do |(key, val), result|
        if val.is_a?(String) && val.start_with?("$")
          parsed = @refs.parse(val.delete_prefix("$"))
          row_keys = (parsed[:legacy] && parsed[:keys].empty?) ? [parsed[:endpoint]] : parsed[:keys]
          resolved = if parsed[:scope] == :meta
            @refs.dig(meta, parsed[:keys])
          else
            @refs.dig(rows.first, row_keys)
          end
          result[key] = resolved.nil? ? val : resolved
        else
          result[key] = val
        end
      end
    end

    def resolve_cell_value(value_ref, row, payload_by_ref_key)
      if value_ref.is_a?(String) && value_ref.start_with?("$")
        parsed = @refs.parse(value_ref.delete_prefix("$"))
        rk = @refs.ref_key(parsed)
        ep_meta = (payload_by_ref_key[rk] || {})["meta"] || {}
        row_keys = (parsed[:legacy] && parsed[:keys].empty?) ? [parsed[:endpoint]] : parsed[:keys]
        (parsed[:scope] == :meta) ? @refs.dig(ep_meta, parsed[:keys]) : @refs.dig(row, row_keys)
      else
        value_ref
      end
    end

    def resolve_filter_value(tmpl, row)
      return tmpl unless tmpl.is_a?(String)

      tmpl.gsub(/\$([a-zA-Z0-9_-]+)\.data\.([a-zA-Z0-9_.]+)/) do
        path = Regexp.last_match(2).split(".")
        @refs.dig(row, path) || Regexp.last_match(0)
      end.gsub(/\$([a-zA-Z0-9_-]+)\.([a-zA-Z0-9_]+)/) do
        field = Regexp.last_match(2)
        next Regexp.last_match(0) if %w[data meta].include?(field)
        (row[field] || row[field.to_sym]) || Regexp.last_match(0)
      end
    end

    # --- Helpers ---

    def detect_ref_key(data_template, rows_by_ref_key = {})
      first_candidate = nil
      data_template.each_value do |val|
        next unless val.is_a?(String) && val.start_with?("$")
        rk = @refs.ref_key_for(val.delete_prefix("$"))
        return rk if rows_by_ref_key.key?(rk)
        first_candidate ||= rk
      end
      first_candidate
    end

    def extract_category_keys(x_ref)
      return nil unless x_ref.is_a?(String) && x_ref.start_with?("$")
      p = @refs.parse(x_ref.delete_prefix("$"))
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

    def build_result(type, fields = {})
      result = {"id" => component["id"], "type" => type}.merge(fields).compact
      result["warnings"] = @warnings if @warnings.any?
      result
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
