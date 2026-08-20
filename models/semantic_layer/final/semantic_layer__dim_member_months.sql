WITH data_with_sks AS (
  SELECT
      mm.person_id
    , mm.data_source
    , mm.member_month_id
    , mm.member_id
    , {{ the_tuva_project.concat_custom(["mm.person_id", "'|'", "mm.data_source"]) }} AS patient_source_key
    , {{ the_tuva_project.concat_custom(["mm.person_id", "'|'", "mm.year_month"]) }} as member_month_sk
    , mm.year_month
    , mm.year_nbr
    , mm.payer
    , mm.{{ the_tuva_project.quote_column('plan') }}
    , mm.payer_attributed_provider
    , mm.payer_attributed_provider_practice
    , mm.payer_attributed_provider_organization
    , mm.payer_attributed_provider_lob
    , mm.custom_attributed_provider
    , mm.custom_attributed_provider_practice
    , mm.custom_attributed_provider_organization
    , mm.custom_attributed_provider_lob
    , mm.tuva_attributed_provider
    , mm.tuva_attributed_provider_bucket
    , mm.tuva_attributed_provider_specialty
    , mm.tuva_last_run
  FROM {{ ref('semantic_layer__stg_core__member_month') }} as mm
)
SELECT
    dws.person_id
  , dws.year_nbr
  , dws.year_month
  , dws.member_month_id
  , dws.member_id
  , dws.member_month_sk
  , dws.data_source
  , dws.patient_source_key
  , dws.payer
  , dws.{{ the_tuva_project.quote_column('plan') }}
  , dws.payer_attributed_provider
  , dws.payer_attributed_provider_practice
  , dws.payer_attributed_provider_organization
  , dws.payer_attributed_provider_lob
  , dws.custom_attributed_provider
  , dws.custom_attributed_provider_practice
  , dws.custom_attributed_provider_organization
  , dws.custom_attributed_provider_lob
  , dws.tuva_attributed_provider
  , dws.tuva_attributed_provider_bucket
  , dws.tuva_attributed_provider_specialty
  , dws.tuva_last_run
FROM data_with_sks as dws
