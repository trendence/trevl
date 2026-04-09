# frozen_string_literal: true

module Trevl
  module DataSource
    class Base
      def fetch(endpoint, params = {}, resource: nil)
        raise NotImplementedError, "#{self.class}#fetch must be implemented"
      end
    end
  end
end
