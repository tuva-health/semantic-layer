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
| `the_tuva_project` (Tuva Core) | 1.0.0 | `0178282263d05010033cc2ed63766466a1722132` |
| `ahrq_quality_indicators` | 1.0.0 | `679873da1b4f1666f5005db2b2ffd6deced07964` |
| `ccsr` | 1.0.0 | `ab26c2d77b8621e6de6315be270afcc8e00f4b95` |
| `cms_hcc` | 1.0.0 | `ae739be31e69c362c44e147d3ee277c584f07b30` |
| `nyu_ed_classification` | 1.0.0 | `3e287e3597aa92fe7514f66439e2cb42d63c6fbd` |
| `quality_measures` | 1.0.0 | `419a76ff5ca4a992a272930860ad9de1eadd29f0` |
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
