#!/usr/bin/env ruby
# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("lib", __dir__))
require "trevl"

puts "TREVL v#{Trevl::VERSION} loaded"

# --- Test 1: Simple bar chart ---
Trevl::DataSource.register("static", Trevl::DataSource::Static.new(
  data: {
    "salary" => {
      "data" => [
        {"label" => "Junior", "value" => 42000},
        {"label" => "Mid-Level", "value" => 58000},
        {"label" => "Senior", "value" => 78000}
      ]
    }
  }
))

yaml1 = <<~YAML
  components:
  - id: salary_bar
    type: chart
    api: static
    highchartsData:
      chart:
        type: bar
      title:
        text: Salary by Seniority
      series:
      - name: Salary
        data:
          x: "$salary.data.label"
          y: "$salary.data.value"
YAML

results = Trevl.render(yaml1)
raise "Test 1 failed: no results" if results.empty?
raise "Test 1 failed: wrong count" unless results.first["highchartsData"]["series"].first["data"].length == 3
puts "Test 1 PASSED: Simple bar chart (3 data points)"

# --- Test 2: Computed fields ---
Trevl::DataSource.reset!
Trevl::DataSource.register("static", Trevl::DataSource::Static.new(
  data: {
    "skills" => {
      "data" => [
        {"name" => "Python", "demand" => 85},
        {"name" => "Ruby", "demand" => 45},
        {"name" => "Go", "demand" => 38}
      ]
    }
  }
))

yaml2 = <<~YAML
  components:
  - id: skills
    type: chart
    api: static
    computed:
    - name: color
      arguments:
        d: "$skills.data.demand"
      code: 'd > 70 ? "#003F85" : "#B0C4DE"'
    highchartsData:
      chart:
        type: column
      series:
      - name: Demand
        data:
          x: "$skills.data.name"
          y: "$skills.data.demand"
          color: "$color"
YAML

results = Trevl.render(yaml2)
colors = results.first["highchartsData"]["series"].first["data"].map { |d| d["color"] }
raise "Test 2 failed: wrong colors #{colors}" unless colors == ["#003F85", "#B0C4DE", "#B0C4DE"]
puts "Test 2 PASSED: Computed fields (colors: #{colors})"

# --- Test 3: Postprocess ---
Trevl::DataSource.reset!
Trevl::DataSource.register("static", Trevl::DataSource::Static.new(
  data: {
    "cities" => {
      "data" => [
        {"city" => "Berlin", "vacancies" => 12500},
        {"city" => "Munich", "vacancies" => 9800},
        {"city" => "Hamburg", "vacancies" => 7200},
        {"city" => "Frankfurt", "vacancies" => 6500},
        {"city" => "Leipzig", "vacancies" => 2100}
      ]
    }
  }
))

yaml3 = <<~YAML
  components:
  - id: top_cities
    type: chart
    api: static
    postprocess: |
      $result = $result
        .sort(function(a, b) { return b.vacancies - a.vacancies; })
        .slice(0, 3);
    highchartsData:
      chart:
        type: bar
      series:
      - name: Vacancies
        data:
          x: "$cities.data.city"
          y: "$cities.data.vacancies"
YAML

results = Trevl.render(yaml3)
cats = results.first["highchartsData"]["xAxis"].first["categories"]
raise "Test 3 failed: #{cats}" unless cats == ["Berlin", "Munich", "Hamburg"]
puts "Test 3 PASSED: Postprocess top-3 (#{cats})"

# --- Test 4: Score ---
Trevl::DataSource.reset!
Trevl::DataSource.register("static", Trevl::DataSource::Static.new(
  data: {
    "kpi" => {
      "data" => [{"avg_salary" => 62100}],
      "meta" => {"median" => 58000}
    }
  }
))

yaml4 = <<~YAML
  components:
  - id: score
    type: score
    api: static
    display:
      value: "$kpi.data.avg_salary"
      unit: " EUR"
      header:
        title: Average Salary
YAML

results = Trevl.render(yaml4)
raise "Test 4 failed" unless results.first["display"]["value"] == 62100
puts "Test 4 PASSED: Score component (value: 62100)"

puts "\nAll tests passed!"
