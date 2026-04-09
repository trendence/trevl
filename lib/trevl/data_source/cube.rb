# frozen_string_literal: true

require "httparty"

module Trevl
  module DataSource
    # Generic CubeJS data source.
    #
    #   Trevl::DataSource.register("cube", Trevl::DataSource::Cube.new(
    #     url: "https://cube.example.com/cubejs-api/v1",
    #     token: ENV["CUBE_TOKEN"]
    #   ))
    #
    class Cube < Base
      include HTTParty

      EMPTY_RESULT = {"data" => [], "meta" => {}}.freeze

      def initialize(url:, token: nil, **)
        super()
        @url = url.to_s.chomp("/")
        @token = token
      end

      def fetch(endpoint, params = {}, resource: nil)
        query = build_query(params)
        headers = {
          "Content-Type" => "application/json",
          "Accept" => "application/json"
        }
        headers["Authorization"] = @token if @token

        Trevl.logger.info("[Trevl::DataSource::Cube] Querying #{@url}/load")

        response = self.class.post(
          "#{@url}/load",
          body: {query: query}.to_json,
          headers: headers,
          timeout: 30
        )

        unless response.success?
          Trevl.logger.error("[Trevl::DataSource::Cube] HTTP #{response.code}: #{response.body}")
          return EMPTY_RESULT.dup
        end

        data = JSON.parse(response.body)
        rows = Array(data["data"]).map { |row| flatten_keys(row) }
        {"data" => rows, "meta" => {}}
      rescue JSON::ParserError, Timeout::Error, Errno::ECONNREFUSED => e
        Trevl.logger.error("[Trevl::DataSource::Cube] Error: #{e.message}")
        EMPTY_RESULT.dup
      end

      private

      def build_query(params)
        query = {}
        query["dimensions"] = params["dimensions"] || params[:dimensions] if params.key?("dimensions") || params.key?(:dimensions)
        query["measures"] = params["measures"] || params[:measures] if params.key?("measures") || params.key?(:measures)
        query["filters"] = params["filters"] || params[:filters] if params.key?("filters") || params.key?(:filters)
        query["timeDimensions"] = params["timeDimensions"] || params[:timeDimensions] if params.key?("timeDimensions") || params.key?(:timeDimensions)
        query["order"] = params["order"] || params[:order] if params.key?("order") || params.key?(:order)
        query["limit"] = params["limit"] || params[:limit] if params.key?("limit") || params.key?(:limit)
        query
      end

      # CubeJS returns keys like "ModelName.fieldName" — flatten to just "fieldName"
      def flatten_keys(row)
        row.each_with_object({}) do |(key, value), flat|
          flat_key = key.to_s.include?(".") ? key.to_s.split(".").last : key.to_s
          flat[flat_key] = value
        end
      end
    end
  end
end
