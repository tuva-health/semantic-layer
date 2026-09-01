with monthly_patient_risk as (
    select
        {{ the_tuva_project.year_month('collection_end_date') }} as year_month
      , person_id
      , payer
      , data_source
      , normalized_risk_score
      , risk_model_code
    from {{ ref('semantic_layer__stg_cms_hcc__patient_risk_scores_monthly') }}
)

, monthly_population_risk as (
    select
        {{ the_tuva_project.year_month('collection_end_date') }} as year_month
      , data_source
      , avg(normalized_risk_score) as monthly_avg_risk_score
    from {{ ref('semantic_layer__stg_cms_hcc__patient_risk_scores_monthly') }}
    group by
        {{ the_tuva_project.year_month('collection_end_date') }}
      , data_source
)

select
    mm.member_month_id
  , mm.data_source
  , mpr.risk_model_code
  , mpr.normalized_risk_score
  , case
      when pop_risk.monthly_avg_risk_score is not null
        and pop_risk.monthly_avg_risk_score != 0
        then mpr.normalized_risk_score / pop_risk.monthly_avg_risk_score
      else null
    end as population_normalized_risk_score
from {{ ref('semantic_layer__stg_core__member_month') }} as mm
left join monthly_patient_risk as mpr
    on mm.person_id = mpr.person_id
   and mm.year_month = mpr.year_month
   and (
        mm.payer = mpr.payer
        or (mm.payer is null and mpr.payer is null)
   )
   and mm.data_source = mpr.data_source
left join monthly_population_risk as pop_risk
    on mm.year_month = pop_risk.year_month
   and mm.data_source = pop_risk.data_source
