{{ config(group='semantic_layer') }}

with staged_encounter_types as (

    select distinct
        encounter_type
    from {{ ref('semantic_layer', 'semantic_layer__stg_core__encounter') }}
    where encounter_type is not null

)

select
    staged.encounter_type
from staged_encounter_types as staged
left join {{ ref('semantic_layer', 'semantic_layer__dim_encounter_type') }} as dim
    on staged.encounter_type = dim.encounter_type
where dim.encounter_type_sk is null
