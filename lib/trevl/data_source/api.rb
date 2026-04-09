# frozen_string_literal: true

require "httparty"

module Trevl
  module DataSource
    # Generic REST API data source. Configure with a base URL and optional auth.
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
        url = build_url(resource, endpoint, params)
        headers = build_headers(url)

        Trevl.logger.info("[Trevl::DataSource::Api] Fetching #{url}")

        response = if post_endpoint?(endpoint)
          self.class.post(url, body: build_body(params).to_json, headers: headers, timeout: 15)
        else
          self.class.get(url, query: params.empty? ? nil : params, headers: headers, timeout: 15)
        end

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

      def build_url(resource, endpoint, _params = {})
        parts = [@base_url]
        parts << resource unless resource.empty?
        parts << endpoint unless endpoint.nil? || endpoint.empty?
        parts.join("/")
      end

      def post_endpoint?(_endpoint)
        true
      end

      def build_body(params)
        params.is_a?(Hash) ? params : {}
      end

      def build_headers(url)
        headers = {
          "Content-Type" => "application/json",
          "Accept" => "application/json"
        }
        @auth&.apply(headers, url: url)
        headers
      end

      def parse_response(body)
        data = JSON.parse(body)
        meta = if data.is_a?(Hash)
          m = data["metadata"] || data["meta"]
          m.is_a?(Hash) ? m : {}
        else
          {}
        end
        rows = case data
        when Array then data
        when Hash
          data["results"] || data["data"] || (data.key?("meta") ? [] : [data])
        else
          []
        end
        rows = Array(rows)
        {"data" => rows, "meta" => meta}
      end
    end
  end
end
