# Semantic Layer integration tests

This consumer project installs exact commits of Tuva Core and every standalone
package required by `semantic_layer`, plus the local package under test. Its
Input Layer models map Tuva Core's shipped small synthetic data into a complete
claims and clinical test build.

Run from the repository root:

```bash
scripts/dbt-local deps
scripts/dbt-local build --full-refresh --indirect-selection cautious --select +package:semantic_layer
```

Local development uses `~/.dbt/profiles.yml`. The `default` profile should use
DuckDB with one thread for stable seed loading. Cautious indirect selection
avoids running upstream relationship tests whose secondary parents are outside
the selected semantic-layer dependency graph.

The required minimum Core configuration can be validated separately with:

```bash
scripts/dbt-local build --full-refresh --indirect-selection cautious \
  --select +package:semantic_layer \
  --vars '{clinical_enabled: false, provider_attribution_enabled: false}'
```
