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
| `the_tuva_project` (Tuva Core) | 1.0.0 | `f90d5fb3c34db92985fa3bc04ef9e44073c634b4` |
| `ahrq_quality_indicators` | 1.0.0 | `77596dee5b32dd94806c55c2c0218a2c3149f05c` |
| `ccsr` | 1.0.0 | `b7d615f8eb008a4f9086bef726097c75f1433da3` |
| `cms_hcc` | 1.0.0 | `bafb601e12b79a394c368c18fa948ec7dc62023a` |
| `nyu_ed_classification` | 1.0.0 | `ad21be1cd30bb0cdfa92ea765017b07ab37ff856` |
| `quality_measures` | 1.0.0 | `b2cfd190b8da9e7f37288f42b4414f1343343389` |
| `dbt_utils` | 1.0.0 | dbt Hub release |

The exact Git pins used by the harness are in
`integration_tests/packages.yml`. Production projects should use a documented
compatible release set when these packages are released.

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

## Release blocker: package-owned seed assets

The integration harness temporarily reads the immutable v0.18 encounter-key
assets from `value-sets/1.0.0`. Before the standalone package can be released,
publish these package-owned gzip assets under `semantic-layer/1.0.0`:

- `semantic_layer__encounter_group_sk.csv.gz`
- `semantic_layer__encounter_type_sk.csv.gz`, including the long-term acute care
  row with key `32`

After publication, remove the private
`_semantic_layer_use_legacy_seed_assets` integration variable and validate the
normal package asset path.
