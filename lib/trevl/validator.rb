# frozen_string_literal: true

require "json_schemer"

module Trevl
  class Validator
    SCHEMA_DIR = File.expand_path("schema", __dir__)
    COMPONENT_SCHEMA_PATH = File.join(SCHEMA_DIR, "component.json")
    DOCUMENT_SCHEMA_PATH = File.join(SCHEMA_DIR, "document.json")

    Result = Struct.new(:valid?, :errors, keyword_init: true) do
      def to_s
        return "Valid" if valid?
        errors.map { |e| "- #{e}" }.join("\n")
      end
    end

    def self.validate(yaml_string)
      new.validate(yaml_string)
    end

    def self.validate_component(component_hash)
      new.validate_component(component_hash)
    end

    def validate(yaml_string)
      parsed = YAML.safe_load(yaml_string, permitted_classes: [Hash, Symbol], aliases: true)
      validate_document(parsed)
    rescue Psych::SyntaxError => e
      Result.new(valid?: false, errors: ["YAML syntax error: #{e.message}"])
    end

    def validate_component(component_hash)
      schema_errors = component_schemer.validate(component_hash).map { |e| format_error(e) }
      Result.new(valid?: schema_errors.empty?, errors: schema_errors)
    end

    def validate_document(parsed)
      if parsed.is_a?(Array)
        validate_component_array(parsed)
      elsif parsed.is_a?(Hash) && parsed["components"].is_a?(Array)
        validate_component_array(parsed["components"])
      elsif parsed.is_a?(Hash)
        Result.new(valid?: false, errors: ["Document must have a 'components' array"])
      else
        Result.new(valid?: false, errors: ["Document must be a Hash or Array, got #{parsed.class}"])
      end
    end

    private

    def validate_component_array(components)
      all_errors = []
      components.each_with_index do |comp, idx|
        schema_errors = component_schemer.validate(comp).map { |e| format_error(e, component_index: idx, component_id: comp["id"]) }
        all_errors.concat(schema_errors)
      end
      Result.new(valid?: all_errors.empty?, errors: all_errors)
    end

    def component_schemer
      @component_schemer ||= JSONSchemer.schema(
        JSON.parse(File.read(COMPONENT_SCHEMA_PATH))
      )
    end

    def format_error(error, component_index: nil, component_id: nil)
      path = error["data_pointer"]
      msg = error["type"]
      details = error["details"] || {}

      prefix = if component_id
        "[#{component_id}]"
      elsif component_index
        "[component ##{component_index}]"
      else
        ""
      end

      case msg
      when "required"
        missing = details["missing_keys"]&.join(", ") || "unknown"
        "#{prefix} Missing required field(s): #{missing} (at #{path})"
      when "enum"
        "#{prefix} Invalid value at #{path}: must be one of #{error["schema"]["enum"].join(", ")}"
      when "type"
        "#{prefix} Wrong type at #{path}: expected #{error["schema"]["type"]}"
      when "object"
        "#{prefix} Schema error at #{path}: #{error["error"]}"
      else
        detail = error["error"] || error.fetch("message", msg)
        "#{prefix} #{detail} (at #{path})"
      end
    end
  end
end
