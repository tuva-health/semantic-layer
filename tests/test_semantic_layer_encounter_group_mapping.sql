{{ config(group='semantic_layer') }}

with staged_encounter_groups as (

    select distinct
        encounter_group
    from {{ ref('semantic_layer', 'semantic_layer__stg_core__encounter') }}
    where encounter_group is not null

)

select
    staged.encounter_group
from staged_encounter_groups as staged
left join {{ ref('semantic_layer', 'semantic_layer__dim_encounter_group') }} as dim
    on staged.encounter_group = dim.encounter_group
where dim.encounter_group_sk is null
