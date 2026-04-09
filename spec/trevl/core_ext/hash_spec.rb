# frozen_string_literal: true

RSpec.describe Trevl::CoreExt::Hash do
  describe ".deep_dup" do
    it "creates a deep copy of nested hashes" do
      original = {"a" => {"b" => [1, 2]}}
      duped = described_class.deep_dup(original)

      duped["a"]["b"] << 3
      expect(original["a"]["b"]).to eq([1, 2])
      expect(duped["a"]["b"]).to eq([1, 2, 3])
    end
  end

  describe ".deep_stringify_keys" do
    it "converts all keys to strings recursively" do
      input = {a: {b: 1}, c: [{d: 2}]}
      result = described_class.deep_stringify_keys(input)

      expect(result).to eq({"a" => {"b" => 1}, "c" => [{"d" => 2}]})
    end
  end

  describe ".deep_merge" do
    it "merges nested hashes" do
      base = {"a" => {"x" => 1, "y" => 2}, "b" => 3}
      override = {"a" => {"y" => 99, "z" => 100}}
      result = described_class.deep_merge(base, override)

      expect(result).to eq({"a" => {"x" => 1, "y" => 99, "z" => 100}, "b" => 3})
    end

    it "override wins for non-hash values" do
      result = described_class.deep_merge({"a" => [1]}, {"a" => [2]})
      expect(result["a"]).to eq([2])
    end
  end
end
