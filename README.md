# TREVL

Write YAML, get Highcharts — in Rails apps, scripts, or iRuby notebooks.

[Trendence](https://www.trendence.com) is a Berlin-based HR data and analytics company. We believe data visualization should be modern, AI-ready, and accessible. That's why we've been building TREVL — the **TR**Endence **V**isualization **L**anguage — a custom DSL designed to make chart creation as simple as writing a few lines of YAML. A language humans easily can use and robots love.

TREVL connects **data sources** (REST APIs, CubeJS, or static data) with **Highcharts** rendering through a simple, human-readable YAML configuration. No JavaScript required for chart definitions.

**Language specification:** [trevl.trendence.com](https://trevl.trendence.com)

## Features

- **Declarative YAML** — define charts, scores, tables, and filters without writing JavaScript
- **Pluggable data sources** — REST APIs, CubeJS, static/in-memory data, or your own
- **Computed fields** — per-row JavaScript transformations (`code` expressions via ExecJS)
- **Postprocess** — full-dataset transformations (sort, filter, aggregate) in JavaScript
- **Template inheritance** — share chart styles across components with deep merge
- **iRuby notebooks** — render interactive Highcharts directly in Jupyter notebooks
- **Offline** — bundled Highcharts JS, no CDN dependency
- **No Rails required** — standalone gem, zero framework dependencies

## Installation

Add to your Gemfile:

```ruby
gem "trevl", github: "trendence/trevl"
```

**Prerequisites:**
- Ruby >= 3.1
- A JavaScript runtime for computed fields (Node.js recommended: `brew install node`)

## Quick Start

```ruby
require "trevl"

# 1. Register a data source
Trevl::DataSource.register("demo", Trevl::DataSource::Static.new(
  data: {
    "salary" => {
      "data" => [
        {"level" => "Junior",  "value" => 42000},
        {"level" => "Senior",  "value" => 78000},
        {"level" => "Lead",    "value" => 92000}
      ]
    }
  }
))

# 2. Render TREVL YAML
results = Trevl.render(<<~YAML)
  components:
  - id: salary_chart
    type: chart
    api: demo
    highchartsData:
      chart:
        type: bar
      title:
        text: Salary by Level
      series:
      - name: Salary (EUR)
        data:
          x: "$salary.data.level"
          y: "$salary.data.value"
YAML

# 3. Use the Highcharts JSON
results.first["highchartsData"]
# => {"chart" => {"type" => "bar"}, "title" => {...}, "series" => [...], "xAxis" => [...]}
```

## iRuby Notebooks

Render interactive charts directly in Jupyter:

```ruby
require "trevl"
require "trevl/notebook"

nb = Trevl::Notebook.new

nb.chart(<<~YAML, data: {"salary" => {"data" => [...]}})
  components:
  - id: chart
    type: chart
    api: static
    highchartsData:
      chart:
        type: column
      series:
      - data:
          x: "$salary.data.level"
          y: "$salary.data.value"
YAML
```

Highcharts is bundled in the gem — charts render offline, no CDN needed.

See [`notebooks/demo.ipynb`](notebooks/demo.ipynb) for 5 working examples including computed fields, postprocess, scores, and templates.

## Data Sources

### Static (in-memory)

```ruby
Trevl::DataSource.register("mydata", Trevl::DataSource::Static.new(
  data: {
    "endpoint_name" => {
      "data" => [{"x" => "A", "y" => 10}, ...],
      "meta" => {"total" => 100}
    }
  }
))
```

### REST API

```ruby
Trevl::DataSource.register("myapi", Trevl::DataSource::Api.new(
  base_url: "https://api.example.com/v1",
  auth: Trevl::Auth::BearerToken.new(ENV["API_TOKEN"])
))
```

### CubeJS

```ruby
Trevl::DataSource.register("cube", Trevl::DataSource::Cube.new(
  url: "https://cube.example.com/cubejs-api/v1",
  token: ENV["CUBE_TOKEN"]
))
```

### Custom

Implement `#fetch(endpoint, params, resource:)` returning `{"data" => [...], "meta" => {...}}`:

```ruby
class MyDatabaseSource < Trevl::DataSource::Base
  def fetch(endpoint, params = {}, resource: nil)
    rows = MyDB.query(endpoint, params)
    {"data" => rows, "meta" => {}}
  end
end

Trevl::DataSource.register("db", MyDatabaseSource.new)
```

## TREVL YAML Reference

### Component Types

| Type | Description |
|------|-------------|
| `chart` | Highcharts visualization (bar, column, line, pie, etc.) |
| `score` | Single KPI value with optional unit and header |
| `table` | Data table with column definitions |
| `text` | Static text/HTML content |
| `filter` | Filter options bound to data |

### Variable References

Reference data fields with `$` syntax:

```yaml
"$endpoint.data.fieldName"           # Row field
"$endpoint.meta.fieldName"           # Metadata field
"$resource.endpoint.data.fieldName"  # With resource qualifier
"$computedFieldName"                 # Computed field (shorthand)
```

### Computed Fields

Per-row JavaScript expressions. Arguments bind `$` references to variables:

```yaml
computed:
- name: color
  arguments:
    val: "$salary.data.value"
  code: 'val > 60000 ? "#003F85" : "#B0C4DE"'
- name: label
  code: '"Salary"'
```

### Postprocess

Transform the full dataset after computed fields:

```yaml
postprocess: |
  $result = $result
    .sort(function(a, b) { return b.value - a.value; })
    .slice(0, 10);
```

### Templates

Register reusable chart configurations:

```ruby
Trevl.template_store.register("blue_bar", {
  "highchartsData" => {
    "chart" => {"type" => "bar"},
    "colors" => ["#003F85"],
    "plotOptions" => {"bar" => {"borderRadius" => 4}}
  }
})
```

```yaml
- id: my_chart
  type: chart
  template: blue_bar        # Inherits all settings
  highchartsData:
    title:
      text: My Chart         # Override only what you need
    series:
    - data:
        y: "$endpoint.data.value"
```

Templates use deep merge: component values override template values at the same path, template values fill in the rest.

### API Parameters

Pass parameters to data sources:

```yaml
- id: chart
  type: chart
  api: myapi
  api-parameters:
    profession:
      id: "43104"
      taxonomy: kldb
    location:
      country: DE
    time:
      start_month_offset: -12
  highchartsData:
    series:
    - data:
        y: "$salary.data.q50"
```

## Authentication

### Bearer Token

```ruby
auth = Trevl::Auth::BearerToken.new("my-secret-token")
```

### Custom

Any object responding to `#apply(headers, url:)`:

```ruby
class MyOAuth < Struct.new(:client_id, :secret)
  def apply(headers, url: nil)
    headers["Authorization"] = "Bearer #{fetch_token}"
  end
end
```

## Configuration

```ruby
Trevl.configure do |c|
  c.logger = Logger.new($stdout, level: :info)
  c.template_store = my_custom_store  # any object with #find(name)
end
```

## Development

```bash
bin/setup              # Install dependencies
bundle exec rspec      # Run tests (72 specs)
bundle exec standardrb # Lint
bin/console            # Interactive console
```

## Language Specification

The full TREVL language specification is available at [trevl.trendence.com](https://trevl.trendence.com), covering:

- Component types and their schemas
- Query definitions and filter operators
- Computed field expression syntax
- Postprocess transformation patterns
- Template inheritance rules
- Data source integration

## License

MIT License. See [LICENSE.txt](LICENSE.txt).
