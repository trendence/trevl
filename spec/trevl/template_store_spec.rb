# frozen_string_literal: true

RSpec.describe Trevl::TemplateStore do
  subject { described_class.new }

  describe "#register / #find" do
    it "stores and retrieves templates by name" do
      subject.register("bar_chart", {"chart" => {"type" => "bar"}})
      expect(subject.find("bar_chart")).to eq({"chart" => {"type" => "bar"}})
    end

    it "is case-insensitive" do
      subject.register("MyTemplate", {"foo" => "bar"})
      expect(subject.find("mytemplate")).to eq({"foo" => "bar"})
      expect(subject.find("MYTEMPLATE")).to eq({"foo" => "bar"})
    end

    it "returns nil for unknown templates" do
      expect(subject.find("nonexistent")).to be_nil
    end
  end

  describe "#names" do
    it "returns all registered template names" do
      subject.register("a", {})
      subject.register("b", {})
      expect(subject.names).to contain_exactly("a", "b")
    end
  end

  describe "#clear" do
    it "removes all templates" do
      subject.register("a", {})
      subject.clear
      expect(subject.names).to be_empty
    end
  end

  describe "#load_yaml" do
    it "bulk-loads templates from YAML string" do
      yaml = <<~YAML
        bar_chart:
          chart:
            type: bar
        pie_chart:
          chart:
            type: pie
      YAML

      subject.load_yaml(yaml)
      expect(subject.find("bar_chart")).to eq({"chart" => {"type" => "bar"}})
      expect(subject.find("pie_chart")).to eq({"chart" => {"type" => "pie"}})
    end
  end
end
