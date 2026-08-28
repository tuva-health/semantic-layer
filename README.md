# Tuva Semantic Layer

[Documentation](https://www.thetuvaproject.com/semantic-layer) |
[Source](https://github.com/tuva-health/semantic-layer)

`semantic_layer` is the standalone dbt package that replaces the semantic-layer
mart formerly bundled with Tuva Core. The first standalone release migrates the
v0.18.0 semantic model onto the Tuva 1.0 package architecture and produces an
analytics-oriented star schema over Core and selected standalone marts.

## Package identity and install topology

- Repository and folder: `semantic-layer`
- dbt project/package name: `semantic_layer`
- Package version: `1.0.0`
- Default output schema: `semantic_layer`, or
  `<tuva_schema_prefix>_semantic_layer` when a prefix is configured
- Required domain: claims (`claims_enabled: true`)
- Public surface: 8 dimensions and 11 facts

The retained v0.18 encounter-fact contract is claims-based. Core 1.0 combines
claim and clinical encounters in `core__encounter`; the encounter staging used
by this package explicitly consumes only rows where
`encounter_source_type = 'claim'`. Encounter-centric facts, including
admissions, retain only rows matching that claim boundary. Clinical encounter
analytics remain outside this package's current scope.

A consuming dbt project installs Tuva Core, the five required standalone marts,
and `semantic_layer` side by side. The semantic package uses package-qualified
refs to those dependencies; it is not part of the `the_tuva_project` dbt
project. Installing it is the opt-in, so there is no `semantic_layer_enabled`
variable. Select its graph with `package:semantic_layer`.

## Tested compatibility set

The local integration harness tests this immutable dependency set. Tuva Core is
pinned to the listed commit from the `tuva-core` `main` branch containing the
latest 1.0.0 changes.

| dbt package | Version | Tested revision |
| --- | --- | --- |
| `the_tuva_project` (Tuva Core) | 1.0.0 | `3d22d5e41082197f396ab8d86c31f9745bb7c16b` |
| `ahrq_quality_indicators` | 1.0.0 | `42a6b42666cb47877b0d96e4d0ee90e44fb0e971` |
| `ccsr` | 1.0.0 | `813acf1eb567dba0429e3664796ea6006f216bfd` |
| `cms_hcc` | 1.0.0 | `4f2454fd73b8d0e63ad0a61fa6309ef200d99caf` |
| `nyu_ed_classification` | 1.0.0 | `c3ac03dbfb214264ecefdbfca04e18cef2a77013` |
| `quality_measures` | 1.0.0 | `db8168b28226a1b605f294bc7cc15c88abe8032a` |
| `dbt_utils` | 1.2.1 | dbt Hub release |

The exact Git pins used by the harness are in
`integration_tests/packages.yml`. Production projects should use a documented
compatible release set when these packages are released. Because these six
packages share the package-seed loader contract, refresh their pins together
whenever that contract changes.

## Migration from the v0.18.0 mart

Downstream two-argument refs must change package name, for example from
`ref('the_tuva_project', 'semantic_layer__fact_claims')` to
`ref('semantic_layer', 'semantic_layer__fact_claims')`. Final relation aliases
such as `fact_claims` and `dim_member_months` are retained.

The following legacy scope is intentionally not carried forward:

- `dim_condition`, `fact_member_condition_bridge`, and their chronic-condition
  staging dependency, because Tuva-defined chronic conditions were retired
- `fact_expected_values` and its predictor/benchmark dependencies, because its
  source contracts were retired and its fallback was only a synthetic null row
- financial-PMPM staging, which is replaced by the Tuva Core `core__cost`
  contract
- pharmacy-expanded staging and the five generic-opportunity fields:
  `generic_available_total_opportunity`, `generic_cost_at_units`,
  `brand_paid_amount`, `generic_available`, and `generic_available_sk`

`fact_pharmacy_claims` remains and is built directly from Core pharmacy claims
and Core terminology.

Member-month models now use Core's `member_month_id` and full coverage grain:
person, member, month, payer, plan, and data source. The legacy
`member_month_sk` is retained only for compatibility and is deprecated because
it is formed from person and month and is not guaranteed unique. Where it is
exposed, new work should join on `member_month_id`.

Provider attribution joins are source-scoped and deterministically ranked. The
valid Core encounter type `inpatient long term acute care` is assigned immutable
semantic key `32`; v0.18.0 omitted it.

## Configuration

The specialty-tier flag in `fact_pharmacy_claims` compares the 30-day
equivalent paid amount with this variable (default `$950`):

```yaml
vars:
  semantic_layer_specialty_tier_threshold: 950
```

`fact_pharmacy_claims` consumes Tuva Core's canonical CodeRx package, drug,
and class routers. Those routers use the bundled CodeRx Open assets by default.
To use user-managed CodeRx Enterprise `packages`, `drugs`, and `classes`
relations in the target database's `coderx` schema instead, configure the
shared Tuva Core variable:

```yaml
vars:
  use_coderx_enterprise: true
```

The Semantic Layer does not read either CodeRx asset family directly, so this
switch applies consistently to Core pharmacy normalization, logical data
quality, medication enrichment, and `fact_pharmacy_claims`.

## Known source-scoping limitations

These outputs preserve the current upstream contracts and therefore cannot yet
be fully separated by `data_source`:

- Upstream readmission sequencing partitions by `person_id`, and several
  upstream joins use `encounter_id`, without `data_source`. The semantic fact
  retains only source-matched claim encounters afterward, but that cannot undo
  cross-source sequencing or attribution already computed upstream. Reused
  person or encounter IDs can therefore affect readmission results.
- `fact_quality_measures` has no `data_source` because the upstream long-form
  quality summary does not expose one.
- `fact_risk_scores`, `fact_risk_factors`, and `fact_hcc_gaps` have no
  `data_source` because the CMS-HCC outputs are scoped by person and payer/model
  context instead. Monthly HCC scores joined into `fact_member_months` share
  the same limitation and can apply across matching source-specific coverage
  rows.

Do not treat these facts as source-isolated when person or encounter identifiers
can overlap across input sources.

## Local validation

Configure a local DuckDB `default` profile, then run from this repository:

```bash
scripts/dbt-local deps
scripts/dbt-local build --full-refresh --indirect-selection cautious --select +package:semantic_layer
```

The integration project uses Tuva Core's shipped small synthetic data and builds
the upstream graph required by this package. Cautious indirect selection avoids
running upstream relationship tests whose secondary parents are outside that
selected dependency graph.

To validate the minimum claims-only Core configuration independently:

```bash
scripts/dbt-local build --full-refresh --indirect-selection cautious \
  --select +package:semantic_layer \
  --vars '{clinical_enabled: false, provider_attribution_enabled: false}'
```

## Package-owned seed assets

The root `data_assets.yml` declares the package-owned encounter-key assets,
which publish as flat gzip objects under `semantic-layer/<package-version>/`:

- `semantic_layer__encounter_group_sk.csv.gz`
- `semantic_layer__encounter_type_sk.csv.gz`, including the long-term acute care
  row with key `32`

The complete reviewed source CSVs live under `data_assets/sources/1.0.0/`; the
CSV files under `seeds/` remain header-only dbt loader contracts. For the 1.0.0
asset release, Tuva Maintenance pins the raw source URLs to the exact reviewed
package commit, canonicalizes the gzip bytes, publishes S3 first, and verifies
the GCS and Azure mirrors before the package release is tagged.
