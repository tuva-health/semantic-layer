with practitioner_deduped as (
    select
        npi
      , data_source
      , specialty
    from (
        select
            npi
          , data_source
          , specialty
          , row_number() over (
                partition by npi, data_source
                order by
                    case when practitioner_id is null then 1 else 0 end
                  , practitioner_id
                  , case when specialty is null then 1 else 0 end
                  , specialty
            ) as row_num
        from {{ ref('semantic_layer__stg_core__practitioner') }}
    ) as ranked
    where row_num = 1
)

, claim_provider_data as (
    select
        c.encounter_id
      , c.data_source
      , c.rendering_npi
      , p.specialty
      , sum(c.paid_amount) as paid_amount
      , max(c.tuva_last_run) as claim_tuva_last_run
  from {{ ref('semantic_layer__stg_core__medical_claim') }} as c
    inner join {{ ref('semantic_layer__dim_data_source') }} as ds on c.data_source = ds.data_source
    left join practitioner_deduped as p
        on c.rendering_npi = p.npi
       and c.data_source = p.data_source
    group by
        c.encounter_id
      , c.data_source
      , c.rendering_npi
      , p.specialty
),
rank_ordered as (
    select
        encounter_id
      , data_source
      , rendering_npi
      , specialty
      , claim_tuva_last_run
      , paid_amount
      , row_number() over (
            partition by encounter_id, data_source
            order by
                coalesce(paid_amount, 0) desc
              , case when rendering_npi is null then 1 else 0 end
              , rendering_npi
              , coalesce(specialty, '') asc
              , case when claim_tuva_last_run is null then 1 else 0 end
              , claim_tuva_last_run desc
        ) as rn
    from claim_provider_data
)

SELECT
    encounter_id
  , data_source
  , rendering_npi as primary_provider_id
  , specialty
  , claim_tuva_last_run as tuva_last_run
from rank_ordered
where rn = 1
