# frozen_string_literal: true

module Trevl
  class Processor
    attr_reader :trevl_content, :processed_content, :parse_errors

    def initialize(trevl_content)
      @trevl_content = trevl_content
      @parse_errors = []
      @processed_content = process_content
    end

    def self.from_hash(trevl_hash)
      new(trevl_hash.to_yaml)
    end

    def components
      @processed_content["components"]
    end

    def component_yaml_content
      comps = @processed_content["components"]
      stringified = if comps.is_a?(Array)
        comps.map { |c| c.is_a?(Hash) ? CoreExt::Hash.deep_stringify_keys(c) : c }
      else
        comps
      end
      YAML.dump(stringified, canonical: false)
    end

    def full_yaml_content
      YAML.dump(CoreExt::Hash.deep_stringify_keys(@processed_content), canonical: false)
    end

    def valid?
      @parse_errors.empty?
    end

    private

    def process_content
      yaml_content = begin
        YAML.safe_load(trevl_content, permitted_classes: [Hash, Symbol], aliases: true)
      rescue Psych::SyntaxError => e
        @parse_errors << "Error parsing TREVL YAML: #{e.message}"
        raise ParseError, "Error parsing TREVL YAML: #{e.message}"
      end

      unless yaml_content.is_a?(Hash) || yaml_content.is_a?(Array)
        @parse_errors << "TREVL content must be a Hash or Array"
        raise ParseError, "TREVL content must be a Hash or Array"
      end

      # Support both top-level hash with "components" key and bare array of components
      if yaml_content.is_a?(Array)
        yaml_content = {"components" => yaml_content}
      end

      if yaml_content["components"].is_a?(Array)
        yaml_content["components"] = apply_templates(yaml_content["components"])
      end

      yaml_content
    rescue ParseError
      raise
    rescue => e
      @parse_errors << "Error processing TREVL content: #{e.message}"
      raise ParseError, "Error processing TREVL content: #{e.message}"
    end

    def apply_templates(components)
      components.map { |component| apply_template_to_component(component) }
    end

    def apply_template_to_component(component)
      return component unless component.is_a?(Hash) && component["template"]

      template_name = component["template"]
      template_hash = Trevl.template_store.find(template_name)
      return component unless template_hash

      deep_merge_with_overwrite(template_hash, component.except("template"))
    end

    def deep_merge_with_overwrite(template_hash, component_hash)
      return component_hash unless template_hash.is_a?(Hash)

      result = {}

      component_hash.each do |key, component_val|
        result[key] = if template_hash.key?(key) && template_hash[key].is_a?(Hash) && component_val.is_a?(Hash)
          deep_merge_with_overwrite(template_hash[key], component_val)
        else
          component_val
        end
      end

      template_hash.each do |key, template_val|
        next if component_hash.key?(key)
        result[key] = template_val
      end

      result
    end
  end
end
