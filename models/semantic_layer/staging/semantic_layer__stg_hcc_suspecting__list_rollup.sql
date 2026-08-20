SELECT
    lr.person_id
  , lr.payer
  , lr.model_version
  , lr.hcc_code
  , lr.hcc_description
  , lr.reason
  , lr.contributing_factor
  , lr.latest_suspect_date
  , cast('{{ var('tuva_last_run') }}' as {{ dbt.type_timestamp() }}) as tuva_last_run
FROM {{ ref('cms_hcc', 'hcc_suspecting__list_rollup') }} as lr
