# frozen_string_literal: true

require_relative "lib/trevl/version"

Gem::Specification.new do |spec|
  spec.name = "trevl"
  spec.version = Trevl::VERSION
  spec.authors = ["Trendence"]
  spec.email = ["dev@trendence.com"]

  spec.summary = "TREVL visualization language engine"
  spec.description = "Parse, render, and display TREVL (Trendence Visualization Language) YAML " \
                      "configurations. Connects data sources to Highcharts through declarative YAML."
  spec.homepage = "https://github.com/trendence/trevl"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/trendence/trevl"
  spec.metadata["documentation_uri"] = "https://trevl.trendence.com"

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/ .standard.yml])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "execjs", "~> 2.9"
  spec.add_dependency "httparty", "~> 0.21"
  spec.add_dependency "json_schemer", "~> 2.0"
end
