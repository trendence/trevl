# frozen_string_literal: true

module Trevl
  class Renderer
    # Parses $-prefixed variable references in TREVL YAML.
    #
    #   parser = RefParser.new
    #   parser.parse("salary.data.q50")
    #   # => {resource: nil, endpoint: "salary", scope: :data, keys: ["q50"]}
    #
    class RefParser
      def parse(ref_without_dollar)
        parts = ref_without_dollar.to_s.split(".")
        resource = nil

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

      def ref_key(parsed)
        [parsed[:resource], parsed[:endpoint]].compact.join("/")
      end

      def ref_key_for(ref_without_dollar)
        ref_key(parse(ref_without_dollar))
      end

      def extract_references(obj)
        refs = []
        case obj
        when Hash then obj.each_value { |v| refs.concat(extract_references(v)) }
        when Array then obj.each { |v| refs.concat(extract_references(v)) }
        when String then refs << obj.delete_prefix("$") if obj.start_with?("$")
        end
        refs.uniq
      end

      def dig(obj, keys)
        return obj if keys.nil? || keys.empty?
        keys.reduce(obj) do |acc, key|
          return nil if acc.nil?
          next nil unless acc.is_a?(Hash)
          acc[key.to_s] || acc[key.to_sym]
        end
      end
    end
  end
end
