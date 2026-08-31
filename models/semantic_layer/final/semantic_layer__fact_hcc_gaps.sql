SELECT
    lr.person_id
  , lr.payer
  , lr.data_source
  , lr.model_version
  , lr.hcc_code
  , lr.hcc_description
  , lr.reason
  , lr.contributing_factor
  , lr.latest_suspect_date
  , lr.tuva_last_run
FROM {{ ref('semantic_layer__stg_hcc_suspecting__list_rollup') }} as lr
