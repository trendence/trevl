# frozen_string_literal: true

module Trevl
  module Auth
    # Simple bearer token authentication.
    #
    #   auth = Trevl::Auth::BearerToken.new("my-secret-token")
    #   Trevl::DataSource::Api.new(base_url: "...", auth: auth)
    #
    # Custom auth objects can be used instead — any object responding to
    # #apply(headers, url:) will work.
    #
    class BearerToken
      def initialize(token)
        @token = token
      end

      def apply(headers, url: nil)
        headers["Authorization"] = "Bearer #{@token}"
      end
    end
  end
end
