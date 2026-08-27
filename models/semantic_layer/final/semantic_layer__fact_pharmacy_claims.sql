{%- set coderx_name_type = 'string' if target.type in ['bigquery', 'databricks'] else 'varchar(3000)' -%}

with coderx_drug_terminology as (
  select
      packages.ndc11
    , packages.drug_id
    , packages.drug_name as package_drug_name
    , coalesce(drugs.drug_name, packages.drug_name) as drug_name
    , coalesce(drugs.is_brand, packages.is_brand) as is_brand
    , classes.atc_1_name
    , classes.atc_2_name
    , classes.atc_3_name
    , classes.atc_4_name
  from {{ ref('the_tuva_project', 'core__stg_coderx_packages') }} as packages
  left outer join {{ ref('the_tuva_project', 'core__stg_coderx_drugs') }} as drugs
    on packages.drug_id = drugs.drug_id
  left outer join {{ ref('the_tuva_project', 'core__stg_coderx_classes') }} as classes
    on packages.drug_id = classes.drug_id
)

select
    p.pharmacy_claim_id
  , p.member_id
  , p.payer
  , p.{{ the_tuva_project.quote_column('plan') }}
  , p.member_month_id
  , p.claim_id
  , p.claim_line_number
  , p.person_id
  , p.data_source
  , {{ the_tuva_project.concat_custom(['p.person_id', "'|'", 'p.data_source']) }} as patient_source_key
  , p.ndc_code
  , coderx.package_drug_name as ndc_description
  , p.paid_amount
  , p.allowed_amount
  , p.prescribing_provider_id
  , p.prescribing_provider_name
  , prac.specialty as prescribing_specialty
  , p.dispensing_provider_id
  , p.dispensing_provider_name
  , p.paid_date
  , p.dispensing_date
  , p.days_supply
  , case
      when p.days_supply = 0 then null
      else p.paid_amount / p.days_supply
    end as cost_per_day
  , case
      when p.days_supply = 0 then null
      else (p.paid_amount / p.days_supply) * 30
    end as thirty_day_equivalent_cost
  , case
      when p.days_supply = 0 then 0
      when (p.paid_amount / p.days_supply) * 30 >= {{ var('semantic_layer_specialty_tier_threshold', 950) }} then 1
      else 0
    end as specialty_tier
  , coderx.drug_id as rxcui
  , coderx.drug_name as rxnorm_description
  , case
      when lower(cast(coderx.is_brand as {{ dbt.type_string() }})) in ('true', '1', 't', 'yes', 'y')
        then coderx.drug_name
      else null
    end as brand_name
  , case
      when lower(cast(coderx.is_brand as {{ dbt.type_string() }})) in ('true', '1', 't', 'yes', 'y')
        then 'brand'
      when lower(cast(coderx.is_brand as {{ dbt.type_string() }})) in ('false', '0', 'f', 'no', 'n')
        then 'generic'
      else null
    end as brand_vs_generic
  , cast(null as {{ coderx_name_type }}) as ingredient_name
  , coderx.atc_1_name
  , coderx.atc_2_name
  , coderx.atc_3_name
  , coderx.atc_4_name
  , p.tuva_last_run
from {{ ref('semantic_layer__stg_core__pharmacy_claim') }} as p
left outer join coderx_drug_terminology as coderx
  on p.ndc_code = coderx.ndc11
left outer join {{ ref('semantic_layer__stg_core__practitioner') }} as prac
  on p.data_source = prac.data_source
 and p.prescribing_provider_id = prac.practitioner_id
