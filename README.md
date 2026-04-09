# TREVL

**TREVL** (Trendence Visualization Language) is a Ruby gem for declarative data visualization. Define charts, scores, tables, and filters in YAML and render them as Highcharts JSON — in Rails apps, scripts, or iRuby notebooks.

## Quick Start

### 1. Install

Add to your Gemfile:

```ruby
gem "trevl", path: "~/trendence/trevl"  # local development
```

Or install directly:

```bash
cd ~/trendence/trevl && bundle exec rake install
```

### 2. Configure a Data Source

```ruby
require "trevl"

# Option A: Static data (great for prototyping)
Trevl::DataSource.register("mydata", Trevl::DataSource::Static.new(
  data: {
    "salary" => {
      "data" => [
        {"label" => "Junior",  "value" => 42000},
        {"label" => "Mid",     "value" => 58000},
        {"label" => "Senior",  "value" => 78000}
      ],
      "meta" => {"currency" => "EUR"}
    }
  }
))

# Option B: REST API
Trevl::DataSource.register("myapi", Trevl::DataSource::Api.new(
  base_url: "https://api.example.com/v1",
  auth: Trevl::Auth::BearerToken.new(ENV["API_TOKEN"])
))

# Option C: CubeJS
Trevl::DataSource.register("cube", Trevl::DataSource::Cube.new(
  url: "https://cube.example.com/cubejs-api/v1",
  token: ENV["CUBE_TOKEN"]
))
```

### 3. Write TREVL YAML

```yaml
# salary_chart.yml
components:
- id: salary_chart
  type: chart
  api: mydata
  highchartsData:
    chart:
      type: bar
    title:
      text: Salary by Seniority
    series:
    - name: Salary (EUR)
      data:
        x: "$salary.data.label"
        y: "$salary.data.value"
```

### 4. Render

```ruby
yaml = File.read("salary_chart.yml")
results = Trevl.render(yaml)
# => [{"id" => "salary_chart", "type" => "chart", "highchartsData" => { ... }}]
```

## iRuby Notebook Usage

### Prerequisites

```bash
# Install iRuby (if not already installed)
gem install iruby
iruby register --force

# Install a JavaScript runtime for computed fields
brew install node  # macOS
```

### In a Notebook Cell

```ruby
require "trevl"
require "trevl/notebook"

# Register static data
Trevl::DataSource.register("demo", Trevl::DataSource::Static.new(
  data: {
    "salary" => {
      "data" => [
        {"label" => "Junior",  "value" => 42000},
        {"label" => "Mid",     "value" => 58000},
        {"label" => "Senior",  "value" => 78000},
        {"label" => "Lead",    "value" => 92000}
      ]
    }
  }
))

nb = Trevl::Notebook.new

# Render a bar chart
nb.chart <<~YAML
  components:
  - id: salary
    type: chart
    api: demo
    highchartsData:
      chart:
        type: bar
      title:
        text: Salary by Level
      colors: ["#003F85"]
      series:
      - name: Salary (EUR)
        data:
          x: "$salary.data.label"
          y: "$salary.data.value"
YAML
```

### Inline Data Override

Skip data source registration and pass data directly:

```ruby
nb.chart(yaml_string, data: {
  "salary" => {
    "data" => [
      {"label" => "Berlin", "value" => 55000},
      {"label" => "Munich", "value" => 62000}
    ]
  }
})
```

### Fetch Raw Data

```ruby
nb.fetch("myapi", "salary", profession: {id: "43104"})
# => {"data" => [...], "meta" => {...}}
```

## TREVL YAML Reference

### Component Types

| Type | Purpose |
|------|---------|
| `chart` | Highcharts visualization (bar, column, line, pie, etc.) |
| `score` | Single KPI value with optional unit |
| `table` | Data table with columns |
| `text` | Static text/HTML content |
| `filter` | Filter options for parameters |

### Variable References

Use `$` to reference data fields in your YAML:

```yaml
# From data rows
"$endpoint.data.fieldName"     # e.g. $salary.data.q50

# From metadata
"$endpoint.meta.fieldName"     # e.g. $salary.meta.total_results

# With resource qualifier
"$resource.endpoint.data.field" # e.g. $surveys.distribution.data.share

# Shorthand (legacy)
"$endpoint.fieldName"          # e.g. $salary.q50
```

### Computed Fields

Transform data per-row using JavaScript expressions:

```yaml
computed:
- name: formatted_salary
  arguments:
    val: "$salary.data.value"
  code: "Math.round(val / 1000) + 'k'"
- name: color
  arguments:
    val: "$salary.data.value"
  code: 'val > 60000 ? "#003F85" : "#999"'
```

### Postprocess

Transform the entire dataset after computed fields:

```yaml
postprocess: |-
  $result = $result
    .sort((a, b) => b.value - a.value)
    .slice(0, 5);
```

### Templates

Share Highcharts configurations across components:

```ruby
Trevl.template_store.register("blue_bar", {
  "highchartsData" => {
    "chart" => {"type" => "bar"},
    "colors" => ["#003F85", "#4A90D9"],
    "plotOptions" => {"bar" => {"borderRadius" => 4}}
  }
})
```

```yaml
components:
- id: my_chart
  type: chart
  template: blue_bar   # inherits all settings, can override any
  api: mydata
  highchartsData:
    title:
      text: My Chart    # overrides only the title
    series:
    - data:
        x: "$salary.data.label"
        y: "$salary.data.value"
```

## Custom Data Sources

Implement your own by subclassing `Trevl::DataSource::Base`:

```ruby
class MyCustomSource < Trevl::DataSource::Base
  def fetch(endpoint, params = {}, resource: nil)
    rows = MyDatabase.query(endpoint, params)
    {"data" => rows, "meta" => {}}
  end
end

Trevl::DataSource.register("mydb", MyCustomSource.new)
```

## Custom Authentication

Any object responding to `#apply(headers, url:)`:

```ruby
class OAuth2Auth
  def initialize(client_id:, client_secret:)
    @client_id = client_id
    @client_secret = client_secret
  end

  def apply(headers, url: nil)
    token = fetch_oauth_token
    headers["Authorization"] = "Bearer #{token}"
  end

  private

  def fetch_oauth_token
    # your OAuth2 flow here
  end
end

Trevl::DataSource.register("api", Trevl::DataSource::Api.new(
  base_url: "https://api.example.com",
  auth: OAuth2Auth.new(client_id: "...", client_secret: "...")
))
```

## Development

```bash
bin/setup          # install dependencies
bundle exec rspec  # run tests
bundle exec standardrb  # lint
bin/console        # interactive console
```

## License

MIT License. See [LICENSE.txt](LICENSE.txt).
