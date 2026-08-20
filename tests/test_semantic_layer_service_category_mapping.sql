{{ config(group='semantic_layer') }}

with eligible_mappable_claims as (

    select distinct
        claims.service_category_1
      , claims.service_category_2
      , claims.service_category_3
    from {{ ref('semantic_layer', 'semantic_layer__stg_core__medical_claim') }} as claims
    inner join {{ ref('semantic_layer', 'semantic_layer__stg_core__encounter') }} as encounters
        on claims.encounter_id = encounters.encounter_id
       and claims.data_source = encounters.data_source
    inner join {{ ref('semantic_layer', 'semantic_layer__dim_encounter_group') }} as encounter_groups
        on encounters.encounter_group = encounter_groups.encounter_group
    inner join {{ ref('semantic_layer', 'semantic_layer__dim_encounter_type') }} as encounter_types
        on encounters.encounter_type = encounter_types.encounter_type
    inner join {{ ref('semantic_layer', 'semantic_layer__dim_data_source') }} as data_sources
        on claims.data_source = data_sources.data_source
    where claims.enrollment_flag = 1
      and claims.service_category_1 is not null
      and claims.service_category_2 is not null
      and claims.service_category_3 is not null

)

select
    claims.service_category_1
  , claims.service_category_2
  , claims.service_category_3
from eligible_mappable_claims as claims
left join {{ ref('semantic_layer', 'semantic_layer__dim_service_category') }} as service_categories
    on claims.service_category_1 = service_categories.service_category_1
   and claims.service_category_2 = service_categories.service_category_2
   and claims.service_category_3 = service_categories.service_category_3
where service_categories.service_category_sk is null
