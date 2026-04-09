# frozen_string_literal: true

RSpec.describe Trevl::Validator do
  describe ".validate" do
    context "valid documents" do
      it "validates a chart component" do
        result = described_class.validate(<<~YAML)
          components:
          - id: c1
            type: chart
            api: myapi
            highchartsData:
              series:
              - data:
                  y: "$endpoint.data.value"
        YAML

        expect(result).to be_valid
        expect(result.errors).to be_empty
      end

      it "validates a score component" do
        result = described_class.validate(<<~YAML)
          components:
          - id: s1
            type: score
            api: myapi
            display:
              value: "$endpoint.data.value"
              unit: "%"
        YAML

        expect(result).to be_valid
      end

      it "validates a text component (no api needed)" do
        result = described_class.validate(<<~YAML)
          components:
          - id: t1
            type: text
            text: "<h1>Hello</h1>"
        YAML

        expect(result).to be_valid
      end

      it "validates a table component" do
        result = described_class.validate(<<~YAML)
          components:
          - id: tbl
            type: table
            api: myapi
            tableData:
              headers: ["Name", "Value"]
              columns:
              - identifier: name
                value: "$endpoint.data.name"
              - identifier: val
                value: "$endpoint.data.value"
        YAML

        expect(result).to be_valid
      end

      it "validates a filter component" do
        result = described_class.validate(<<~YAML)
          components:
          - id: f1
            type: filter
            api: myapi
            filters:
            - id: gender_filter
              type: select
              label: Gender
              options:
                value: "$endpoint.data.id"
                label: "$endpoint.data.name"
        YAML

        expect(result).to be_valid
      end

      it "validates a bare array of components" do
        result = described_class.validate(<<~YAML)
          - id: c1
            type: text
            text: "Hello"
        YAML

        expect(result).to be_valid
      end

      it "validates components with computed fields" do
        result = described_class.validate(<<~YAML)
          components:
          - id: c1
            type: chart
            api: myapi
            computed:
            - name: color
              arguments:
                val: "$endpoint.data.value"
              code: 'val > 50 ? "blue" : "gray"'
            highchartsData:
              series:
              - data:
                  y: "$endpoint.data.value"
                  color: "$color"
        YAML

        expect(result).to be_valid
      end

      it "validates components with postprocess" do
        result = described_class.validate(<<~YAML)
          components:
          - id: c1
            type: chart
            api: myapi
            postprocess: |
              $result = $result.slice(0, 5);
            highchartsData:
              series:
              - data:
                  y: "$endpoint.data.value"
        YAML

        expect(result).to be_valid
      end

      it "validates components with template reference" do
        result = described_class.validate(<<~YAML)
          components:
          - id: c1
            type: chart
            api: myapi
            template: blue_bar
            highchartsData:
              series:
              - data:
                  y: "$endpoint.data.value"
        YAML

        expect(result).to be_valid
      end
    end

    context "invalid documents" do
      it "reports missing id" do
        result = described_class.validate(<<~YAML)
          components:
          - type: chart
            api: myapi
            highchartsData:
              series: []
        YAML

        expect(result).not_to be_valid
        expect(result.errors.any? { |e| e.include?("id") }).to be true
      end

      it "reports missing type" do
        result = described_class.validate(<<~YAML)
          components:
          - id: c1
            api: myapi
        YAML

        expect(result).not_to be_valid
        expect(result.errors.any? { |e| e.include?("type") }).to be true
      end

      it "reports invalid type value" do
        result = described_class.validate(<<~YAML)
          components:
          - id: c1
            type: invalid_type
        YAML

        expect(result).not_to be_valid
        expect(result.errors.any? { |e| e.include?("chart") || e.include?("enum") }).to be true
      end

      it "reports chart missing highchartsData" do
        result = described_class.validate(<<~YAML)
          components:
          - id: c1
            type: chart
            api: myapi
        YAML

        expect(result).not_to be_valid
        expect(result.errors.any? { |e| e.include?("highchartsData") }).to be true
      end

      it "reports chart missing api" do
        result = described_class.validate(<<~YAML)
          components:
          - id: c1
            type: chart
            highchartsData:
              series: []
        YAML

        expect(result).not_to be_valid
        expect(result.errors.any? { |e| e.include?("api") }).to be true
      end

      it "reports score missing display" do
        result = described_class.validate(<<~YAML)
          components:
          - id: s1
            type: score
            api: myapi
        YAML

        expect(result).not_to be_valid
        expect(result.errors.any? { |e| e.include?("display") }).to be true
      end

      it "reports invalid YAML syntax" do
        result = described_class.validate("- [broken: yaml: :")
        expect(result).not_to be_valid
        expect(result.errors.first).to include("YAML syntax error")
      end

      it "reports computed field missing code" do
        result = described_class.validate(<<~YAML)
          components:
          - id: c1
            type: chart
            api: myapi
            computed:
            - name: test
            highchartsData:
              series:
              - data:
                  y: "$endpoint.data.value"
        YAML

        expect(result).not_to be_valid
        expect(result.errors.any? { |e| e.include?("code") }).to be true
      end

      it "includes component id in error messages" do
        result = described_class.validate(<<~YAML)
          components:
          - id: my_broken_chart
            type: chart
        YAML

        expect(result.errors.any? { |e| e.include?("my_broken_chart") }).to be true
      end
    end

    context "multiple components" do
      it "validates each component independently" do
        result = described_class.validate(<<~YAML)
          components:
          - id: good
            type: text
            text: "Hello"
          - id: bad
            type: chart
        YAML

        expect(result).not_to be_valid
        expect(result.errors.any? { |e| e.include?("bad") }).to be true
        expect(result.errors.none? { |e| e.include?("good") }).to be true
      end
    end
  end

  describe ".validate_component" do
    it "validates a single component hash" do
      result = described_class.validate_component({
        "id" => "c1",
        "type" => "text",
        "text" => "Hello"
      })

      expect(result).to be_valid
    end

    it "reports errors for invalid component" do
      result = described_class.validate_component({
        "type" => "chart"
      })

      expect(result).not_to be_valid
    end
  end

  describe "Result#to_s" do
    it "returns 'Valid' for valid results" do
      result = Trevl::Validator::Result.new(valid?: true, errors: [])
      expect(result.to_s).to eq("Valid")
    end

    it "formats errors as bullet list" do
      result = Trevl::Validator::Result.new(valid?: false, errors: ["Error 1", "Error 2"])
      expect(result.to_s).to eq("- Error 1\n- Error 2")
    end
  end
end
