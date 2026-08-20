SELECT
    rsm.person_id
  , rsm.payer
  , rsm.risk_model_code
  , rsm.enrollment_status
  , rsm.payment_year
  , rsm.collection_start_date
  , rsm.collection_end_date
  , rsm.normalized_risk_score
  , cast('{{ var('tuva_last_run') }}' as {{ dbt.type_timestamp() }}) as tuva_last_run
FROM {{ ref('cms_hcc', 'cms_hcc__patient_risk_scores_monthly') }} as rsm
