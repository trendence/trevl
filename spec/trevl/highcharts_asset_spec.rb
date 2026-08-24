# frozen_string_literal: true

require "tempfile"

RSpec.describe Trevl::HighchartsAsset do
  it "references the CDN by default" do
    expect(described_class.script_tags)
      .to eq(%(<script src="https://code.highcharts.com/11.4.0/highcharts.js"></script>))
  end

  it "follows a configured CDN url" do
    Trevl.configure { |c| c.highcharts_url = "https://example.test/hc.js" }

    expect(described_class.script_tags).to eq(%(<script src="https://example.test/hc.js"></script>))
  end

  it "inlines a local file instead of linking it" do
    with_local_file("// build") do |path|
      Trevl.configure { |c| c.highcharts_path = path }

      expect(described_class.script_tags).to eq("<script>// build</script>")
    end
  end

  it "raises when the configured local file is missing" do
    Trevl.configure { |c| c.highcharts_path = "/no/such/highcharts.js" }

    expect { described_class.script_tags }
      .to raise_error(Trevl::Error, %r{/no/such/highcharts\.js})
  end

  it "appends configured modules as urls" do
    Trevl.configure { |c| c.highcharts_modules = ["https://example.test/more.js"] }

    expect(described_class.script_tags).to include(%(<script src="https://example.test/more.js"></script>))
  end

  it "inlines modules given as local paths" do
    with_local_file("// more") do |path|
      Trevl.configure { |c| c.highcharts_modules = [path] }

      expect(described_class.script_tags).to include("<script>// more</script>")
    end
  end

  def with_local_file(contents)
    Tempfile.create(["highcharts", ".js"]) do |file|
      file.write(contents)
      file.flush
      yield file.path
    end
  end
end
