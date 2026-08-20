SELECT
    rf.person_id
  , rf.payer
  , rf.factor_type
  , rf.risk_factor_description
  , rf.coefficient
  , rf.model_version
  , rf.payment_year
  , cast('{{ var('tuva_last_run') }}' as {{ dbt.type_timestamp() }}) as tuva_last_run
FROM {{ ref('cms_hcc', 'cms_hcc__patient_risk_factors') }} as rf
