<p align="center">
  <img src="assets/trevl-logo.svg" alt="TREVL" width="220" />
</p>

<h3 align="center">Write YAML, get Highcharts.</h3>

<p align="center">
  <a href="https://trevl.trendence.com">Language Spec</a> &middot;
  <a href="notebooks/demo.ipynb">Demo Notebook</a> &middot;
  <a href="https://github.com/trendence/trevl">GitHub</a>
</p>

---

[Trendence](https://www.trendence.com) is a Berlin-based HR data and analytics company. We believe data visualization should be modern, AI-ready, and accessible. That's why we've been building TREVL -- the **TR**Endence **V**isualization **L**anguage -- a custom DSL designed to make chart creation as simple as writing a few lines of YAML. A language humans easily can use and robots love.

## Features

- **Declarative YAML** -- define charts, scores, tables, and filters without writing JavaScript
- **Pluggable data sources** -- REST APIs, CubeJS, static/in-memory data, or build your own
- **Computed fields** -- per-row JavaScript transformations via ExecJS
- **Postprocess** -- full-dataset transforms (sort, filter, aggregate) in JavaScript
- **Template inheritance** -- share chart styles with deep merge
- **iRuby notebooks** -- render interactive Highcharts directly in Jupyter
- **Fully offline** -- bundled Highcharts JS, no CDN needed
- **Standalone** -- no Rails, no framework dependencies

## Installation

```ruby
gem "trevl", github: "trendence/trevl"
```

**Prerequisites:** Ruby >= 3.1, Node.js (`brew install node`) for computed fields.

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

# 2. Render
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

# 3. Done -- results.first["highchartsData"] is ready for Highcharts
```

## iRuby Notebooks

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

Highcharts is bundled -- charts render offline. See [`notebooks/demo.ipynb`](notebooks/demo.ipynb) for 5 working examples.

## Data Sources

### Static (in-memory)

```ruby
Trevl::DataSource.register("mydata", Trevl::DataSource::Static.new(
  data: {"endpoint" => {"data" => [...], "meta" => {...}}}
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

```ruby
class MySource < Trevl::DataSource::Base
  def fetch(endpoint, params = {}, resource: nil)
    {"data" => MyDB.query(endpoint, params), "meta" => {}}
  end
end

Trevl::DataSource.register("db", MySource.new)
```

## YAML Reference

### Component Types

| Type | Description |
|------|-------------|
| `chart` | Highcharts visualization (bar, column, line, pie, ...) |
| `score` | Single KPI value with optional unit |
| `table` | Data table with column definitions |
| `text` | Static text / HTML content |
| `filter` | Filter options bound to data |

### Variable References

```yaml
"$endpoint.data.fieldName"             # data row field
"$endpoint.meta.fieldName"             # metadata field
"$resource.endpoint.data.fieldName"    # with resource qualifier
"$computedFieldName"                   # computed field shorthand
```

### Computed Fields

Per-row JavaScript expressions:

```yaml
computed:
- name: color
  arguments:
    val: "$salary.data.value"
  code: 'val > 60000 ? "#003F85" : "#ccc"'
```

### Postprocess

Full-dataset JavaScript transforms:

```yaml
postprocess: |
  $result = $result
    .sort((a, b) => b.value - a.value)
    .slice(0, 10);
```

### Templates

```ruby
Trevl.template_store.register("blue_bar", {
  "highchartsData" => {
    "chart" => {"type" => "bar"},
    "colors" => ["#003F85"]
  }
})
```

```yaml
- id: my_chart
  template: blue_bar
  highchartsData:
    title:
      text: My Chart
```

Deep merge: component overrides template at the same path.

## Auth

```ruby
# Bearer token
auth = Trevl::Auth::BearerToken.new("token")

# Custom -- any object with #apply(headers, url:)
class MyAuth
  def apply(headers, url: nil)
    headers["Authorization"] = "Bearer #{fetch_token}"
  end
end
```

## Configuration

```ruby
Trevl.configure do |c|
  c.logger = Logger.new($stdout, level: :info)
  c.template_store = my_custom_store
end
```

## Development

```bash
bin/setup              # install dependencies
bundle exec rspec      # 72 specs
bundle exec standardrb # lint
bin/console            # interactive console
```

## Language Specification

The full TREVL v3.0 specification lives at **[trevl.trendence.com](https://trevl.trendence.com)** -- covering component schemas, query definitions, filter operators, computed fields, postprocess patterns, template inheritance, and data source integration.

## License

MIT -- see [LICENSE.txt](LICENSE.txt).
