# frozen_string_literal: true

module Trevl
  class Error < StandardError; end
  class ParseError < Error; end
  class ValidationError < Error; end
  class DataSourceError < Error; end
  class RenderError < Error; end
end
