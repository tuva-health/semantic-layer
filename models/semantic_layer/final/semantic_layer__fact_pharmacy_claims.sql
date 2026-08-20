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
  , coalesce(n.fda_description, n.rxnorm_description) as ndc_description
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
  , n.rxcui
  , n.rxnorm_description
  , r.brand_name
  , r.brand_vs_generic
  , r.ingredient_name
  , a.atc_1_name
  , a.atc_2_name
  , a.atc_3_name
  , a.atc_4_name
  , p.tuva_last_run
from {{ ref('semantic_layer__stg_core__pharmacy_claim') }} as p
left outer join {{ ref('the_tuva_project', 'terminology__ndc') }} as n
  on p.ndc_code = n.ndc
left outer join {{ ref('the_tuva_project', 'terminology__rxnorm_brand_generic') }} as r
  on n.rxcui = r.product_rxcui
left outer join {{ ref('the_tuva_project', 'terminology__rxnorm_to_atc') }} as a
  on n.rxcui = a.rxcui
left outer join {{ ref('semantic_layer__stg_core__practitioner') }} as prac
  on p.data_source = prac.data_source
 and p.prescribing_provider_id = prac.practitioner_id
