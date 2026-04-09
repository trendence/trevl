# frozen_string_literal: true

require "httparty"

module Trevl
  module DataSource
    # Generic REST API data source.
    #
    #   Trevl::DataSource.register("my_api", Trevl::DataSource::Api.new(
    #     base_url: "https://api.example.com/v1",
    #     auth: Trevl::Auth::BearerToken.new("my-token")
    #   ))
    #
    class Api < Base
      include HTTParty

      EMPTY_RESULT = {"data" => [], "meta" => {}}.freeze

      attr_reader :base_url

      def initialize(base_url:, auth: nil, default_resource: nil, **)
        super()
        @base_url = base_url.to_s.chomp("/")
        @auth = auth
        @default_resource = default_resource
      end

      def fetch(endpoint, params = {}, resource: nil)
        resource = (resource || @default_resource).to_s
        url = build_url(resource, endpoint)
        headers = build_headers(url)
        body = params.is_a?(Hash) ? params : {}

        Trevl.logger.info("[Trevl::DataSource::Api] POST #{url}")

        response = self.class.post(url, body: body.to_json, headers: headers, timeout: 15)

        unless response.success?
          Trevl.logger.error("[Trevl::DataSource::Api] HTTP #{response.code} from #{url}")
          return EMPTY_RESULT.dup
        end

        parse_response(response.body)
      rescue JSON::ParserError, Timeout::Error, Errno::ECONNREFUSED => e
        Trevl.logger.error("[Trevl::DataSource::Api] Error: #{e.message}")
        EMPTY_RESULT.dup
      end

      private

      def build_url(resource, endpoint)
        parts = [@base_url]
        parts << resource unless resource.empty?
        parts << endpoint unless endpoint.nil? || endpoint.empty?
        parts.join("/")
      end

      def build_headers(url)
        headers = {"Content-Type" => "application/json", "Accept" => "application/json"}
        @auth&.apply(headers, url: url)
        headers
      end

      def parse_response(body)
        data = JSON.parse(body)
        meta = extract_meta(data)
        rows = extract_rows(data)
        {"data" => rows, "meta" => meta}
      end

      def extract_meta(data)
        return {} unless data.is_a?(Hash)
        m = data["metadata"] || data["meta"]
        m.is_a?(Hash) ? m : {}
      end

      def extract_rows(data)
        case data
        when Array then data
        when Hash then data["results"] || data["data"] || (data.key?("meta") ? [] : [data])
        else []
        end
      end
    end
  end
end
