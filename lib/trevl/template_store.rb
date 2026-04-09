# frozen_string_literal: true

module Trevl
  class TemplateStore
    def initialize
      @templates = {}
    end

    def register(name, template_hash)
      @templates[name.to_s.downcase] = template_hash
    end

    def find(name)
      @templates[name.to_s.downcase]
    end

    def load_yaml(yaml_string)
      data = YAML.safe_load(yaml_string, permitted_classes: [Hash], aliases: true)
      return unless data.is_a?(Hash)

      data.each do |name, template_hash|
        register(name, template_hash) if template_hash.is_a?(Hash)
      end
    end

    def load_file(path)
      load_yaml(File.read(path))
    end

    def names
      @templates.keys
    end

    def clear
      @templates.clear
    end
  end
end
