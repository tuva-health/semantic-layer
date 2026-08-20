{{ config(group='semantic_layer') }}

with expected as (

    select
        'inpatient long term acute care' as encounter_type
      , cast('32' as {{ dbt.type_string() }}) as encounter_type_sk
      , cast('1' as {{ dbt.type_string() }}) as encounter_group_sk

)

select
    expected.*
from expected
left join {{ ref('semantic_layer', 'semantic_layer__dim_encounter_type') }} as actual
    on expected.encounter_type = actual.encounter_type
    and expected.encounter_type_sk = actual.encounter_type_sk
    and expected.encounter_group_sk = actual.encounter_group_sk
where actual.encounter_type is null
