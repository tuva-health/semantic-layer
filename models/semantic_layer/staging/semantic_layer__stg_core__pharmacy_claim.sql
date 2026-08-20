select
    p.pharmacy_claim_id
  , p.claim_id
  , p.claim_line_number
  , p.person_id
  , p.member_id
  , p.payer
  , p.{{ the_tuva_project.quote_column('plan') }}
  , p.member_month_id
  , p.data_source
  , p.ndc_code
  , p.paid_amount
  , p.allowed_amount
  , p.prescribing_provider_id
  , p.prescribing_provider_name
  , p.dispensing_provider_id
  , p.dispensing_provider_name
  , p.paid_date
  , p.dispensing_date
  , p.days_supply
  , p.quantity
  , p.tuva_last_run
from {{ ref('the_tuva_project', 'core__pharmacy_claim') }} as p
