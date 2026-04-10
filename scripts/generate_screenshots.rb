#!/usr/bin/env ruby
# frozen_string_literal: true

# Generates PNG screenshots for all TREVL examples.
# Usage: ruby scripts/generate_screenshots.rb

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "trevl"
require "grover"

OUTPUT_DIR = File.expand_path("../docs/screenshots", __dir__)

EXAMPLE_DATA = {
  "01_bar_chart" => {
    "pirates" => {"data" => [
      {"name" => "Guybrush", "barrels" => 12},
      {"name" => "LeChuck", "barrels" => 47},
      {"name" => "Elaine", "barrels" => 3},
      {"name" => "Stan", "barrels" => 28},
      {"name" => "Murray", "barrels" => 0}
    ]}
  },
  "02_column_chart" => {
    "loot" => {"data" => [
      {"quarter" => "Q1", "doubloons" => 3200},
      {"quarter" => "Q2", "doubloons" => 8100},
      {"quarter" => "Q3", "doubloons" => 5400},
      {"quarter" => "Q4", "doubloons" => 12600}
    ]}
  },
  "03_line_chart" => {
    "monkeys" => {"data" => [
      {"month" => "Jan", "sightings" => 3},
      {"month" => "Feb", "sightings" => 5},
      {"month" => "Mar", "sightings" => 2},
      {"month" => "Apr", "sightings" => 8},
      {"month" => "May", "sightings" => 12},
      {"month" => "Jun", "sightings" => 7}
    ]}
  },
  "04_pie_chart" => {
    "candidates" => {"data" => [
      {"candidate" => "Guybrush Threepwood", "votes" => 42},
      {"candidate" => "Carla the Sword Master", "votes" => 31},
      {"candidate" => "Stan S. Stanman", "votes" => 18},
      {"candidate" => "Murray the Skull", "votes" => 9}
    ]}
  },
  "05_computed_fields" => {
    "pirates" => {"data" => [
      {"name" => "Guybrush", "skill" => 92},
      {"name" => "Carla", "skill" => 98},
      {"name" => "Captain Smirk", "skill" => 75},
      {"name" => "LeChuck", "skill" => 45},
      {"name" => "Stan", "skill" => 62}
    ]}
  },
  "06_postprocess_top_n" => {
    "islands" => {"data" => [
      {"name" => "Monkey Island", "buried" => 42},
      {"name" => "Melee Island", "buried" => 28},
      {"name" => "Booty Island", "buried" => 35},
      {"name" => "Phatt Island", "buried" => 19},
      {"name" => "Scabb Island", "buried" => 31},
      {"name" => "Lucre Island", "buried" => 15},
      {"name" => "Jambalaya Island", "buried" => 22},
      {"name" => "Blood Island", "buried" => 8}
    ]}
  },
  "10_multi_series" => {
    "sales" => {"data" => [
      {"month" => "Jan", "grog" => 340, "rum" => 120},
      {"month" => "Feb", "grog" => 280, "rum" => 150},
      {"month" => "Mar", "grog" => 410, "rum" => 180},
      {"month" => "Apr", "grog" => 520, "rum" => 210},
      {"month" => "May", "grog" => 380, "rum" => 190},
      {"month" => "Jun", "grog" => 600, "rum" => 250}
    ]}
  }
}

SKIP = %w[07_score_kpi 08_table 09_template_inheritance]

Dir.glob(File.join(File.expand_path("../examples", __dir__), "*.yml")).sort.each do |path|
  name = File.basename(path, ".yml")
  next if SKIP.include?(name)

  data = EXAMPLE_DATA[name]
  unless data
    puts "SKIP #{name} (no sample data)"
    next
  end

  Trevl::DataSource.reset!
  Trevl::DataSource.register("demo", Trevl::DataSource::Static.new(data: data))

  yaml = File.read(path).sub(/\A(#[^\n]*\n)+/, "")

  html = Trevl.render_to_html(yaml, width: 800, height: 400)
  png = Grover.new(html, format: "png", viewport: {width: 900, height: 500}).to_png

  output_path = File.join(OUTPUT_DIR, "#{name}.png")
  File.write(output_path, png)
  puts "OK #{name}.png (#{File.size(output_path)} bytes)"
end

puts "\nDone! Screenshots in #{OUTPUT_DIR}"
