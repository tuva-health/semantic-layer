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
- Package version: `0.1.0`
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

## Prerequisites

Use this package from a connector or other root dbt project that maps source
data into Tuva's Input Layer and owns the complete package set. The root project
must install:

- Tuva Core with claims enabled
- AHRQ Quality Indicators
- CCSR
- CMS HCC
- NYU ED Classification
- Quality Measures
- this Semantic Layer package

The package requires dbt Core or Fusion `>=1.10.5,<3.0.0`. It is claims-based:
`claims_enabled` must be the native YAML boolean `true`. The root project may
also enable clinical data, but clinical encounters are not added to the
claims-based encounter facts.

## Installation

Declare the compatible package set once in the consuming project's
`packages.yml`. Do not add a second copy of Tuva Core within an individual mart.
After the Tuva 1.0 releases are available on dbt Hub, the installation is:

```yaml
packages:
  - package: tuva-health/the_tuva_project
    version: 1.0.0
  - package: tuva-health/ahrq_quality_indicators
    version: 0.1.0
  - package: tuva-health/ccsr
    version: 0.1.0
  - package: tuva-health/cms_hcc
    version: 0.1.0
  - package: tuva-health/nyu_ed_classification
    version: 0.1.0
  - package: tuva-health/quality_measures
    version: 0.1.0
  - package: tuva-health/semantic_layer
    version: 0.1.0
```

During the Tuva 1.0 prerelease window, use the same topology with exact Git
tags or verified commits from the corresponding `tuva-health` repositories.
The immutable revisions used by this repository's integration harness are
listed below.

Install dependencies and build the required upstream graph from the root
project:

```bash
dbt deps
dbt build --select +package:semantic_layer
```

## Tested compatibility set

The local integration harness tests this immutable dependency set. Tuva Core is
pinned to the listed commit from the `tuva-core` `main` branch containing the
latest 1.0.0 changes.

| dbt package | Version | Tested revision |
| --- | --- | --- |
| `the_tuva_project` (Tuva Core) | 1.0.0 | `818191853771dec267fd9d6fe0edd68be74308e6` |
| `ahrq_quality_indicators` | 0.1.0 | `0946e1c4d184024f91467dd08cc6d0be4f126da9` |
| `ccsr` | 0.1.0 | `768a4aa03df951c10638f54c85d3db9ec246a5cc` |
| `cms_hcc` | 0.1.0 | `3b249b52ab428771548d1a52ade7b6e291ab8667` |
| `nyu_ed_classification` | 0.1.0 | `e2dbeb93e96f97b3d42b30ea57dc3c52aa610eba` |
| `quality_measures` | 0.1.0 | `88e490409e4ff5cd0ee7b61e189d88548daec76f` |
| `dbt_utils` | >=1.3.2,<2.0.0 | dbt Hub release range |

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

## Source-scoping contract

The tested dependency set publishes source-scoped AHRQ PQI, readmission,
quality-measure, CMS-HCC, HCC-suspecting, NYU ED, and Core contracts. Semantic
Layer joins and grains preserve `data_source` wherever a person, encounter,
claim, provider, or coverage identity is source-native. In particular:

- admission, encounter, claim, ED-visit, and encounter-provider joins use
  `encounter_id` together with `data_source`;
- quality-measure, annual risk, risk-factor, and HCC-gap facts publish
  `data_source` as part of their tested grain; and
- monthly risk and cost enrichment joins to the complete Core member-month
  coverage identity without crossing sources.

Reference dimensions such as date, encounter type, encounter group, and
service category are intentionally source-neutral. The deprecated
`member_month_sk` compatibility field is still not guaranteed unique; new
work should use Core's `member_month_id`.

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

The package-owned encounter-key assets load as flat gzip objects from
`data-marts/semantic-layer/<asset-version>/`:

- `semantic_layer__encounter_group_sk.csv.gz`
- `semantic_layer__encounter_type_sk.csv.gz`, including the long-term acute care
  row with key `32`

The CSV files under `seeds/` are header-only dbt loader contracts, and the seed
YAML defines the relations, types, and tests.
`semantic_layer_data_asset_version` selects the folder and defaults to `1.0.0`.
The data-asset version is intentionally independent of this package's code
version, and maintainers coordinate the two values when an asset changes.
Cloud `_manifest.json` and `_release.json` files are maintenance metadata and
are not read by dbt at runtime.

## Supported warehouses

The complete Tuva 1.0 package graph is validated on Snowflake, BigQuery,
Databricks, Microsoft Fabric, Redshift, and DuckDB. The Semantic Layer also
contains adapter dispatches for Microsoft SQL Server and Amazon Athena, but
those adapters are not currently part of Tuva's end-to-end Core support matrix.

Please report reproducible adapter differences in the
[GitHub repository](https://github.com/tuva-health/semantic-layer/issues).

## Development and license

The integration project pins every upstream repository to a 40-character
commit so CI tests one reproducible graph. Run the commands in **Local
validation** before submitting a change, and update the compatibility table
whenever those pins change.

This project is licensed under the [Apache License 2.0](LICENSE.txt).
