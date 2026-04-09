# frozen_string_literal: true

RSpec.describe "AI-first tooling" do
  describe "Trevl.schema_reference" do
    it "returns the llms.txt content" do
      ref = Trevl.schema_reference
      expect(ref).to include("TREVL")
      expect(ref).to include("Component Types")
      expect(ref).to include("Variable Reference Syntax")
      expect(ref).to include("Computed Fields")
      expect(ref).to include("Postprocess")
    end

    it "is under 3000 tokens (~12000 chars)" do
      expect(Trevl.schema_reference.length).to be < 12000
    end
  end

  describe "Trevl.examples" do
    it "returns an array of example hashes" do
      examples = Trevl.examples
      expect(examples).to be_an(Array)
      expect(examples.length).to be >= 10
    end

    it "each example has name, description, and yaml" do
      Trevl.examples.each do |ex|
        expect(ex[:name]).to be_a(String)
        expect(ex[:description]).to be_a(String)
        expect(ex[:description]).not_to be_empty
        expect(ex[:yaml]).to be_a(String)
        expect(ex[:yaml]).to include("type:")
      end
    end

    it "example YAML is valid TREVL" do
      Trevl.examples.each do |ex|
        result = Trevl.validate(ex[:yaml])
        expect(result).to be_valid, "Example '#{ex[:name]}' is invalid: #{result.errors.join(", ")}"
      end
    end
  end

  describe "DataSource::Base#field_names" do
    it "returns field names from a sample row" do
      source = Trevl::DataSource::Static.new(
        data: {
          "salary" => {
            "data" => [{"q10" => 30000, "q50" => 45000, "q90" => 72000}],
            "meta" => {}
          }
        }
      )

      expect(source.field_names("salary")).to eq(["q10", "q50", "q90"])
    end

    it "returns empty array for unknown endpoints" do
      source = Trevl::DataSource::Static.new(data: {})
      expect(source.field_names("missing")).to eq([])
    end

    it "works through the registry" do
      Trevl::DataSource.register("test", Trevl::DataSource::Static.new(
        data: {"ep" => {"data" => [{"a" => 1, "b" => 2}]}}
      ))

      source = Trevl::DataSource.for("test")
      expect(source.field_names("ep")).to eq(["a", "b"])
    end
  end
end
