SELECT
    mm.person_id
  , mm.data_source
  , mm.member_month_id
  , mm.member_id
  , left(mm.year_month, 4) AS year_nbr
  , mm.year_month
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
FROM {{ ref('the_tuva_project', 'core__member_month') }} mm
