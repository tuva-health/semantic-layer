with encounter_types as (
    select
        encounter_type
      , encounter_type_sk
      , encounter_group_sk
    from {{ ref('semantic_layer__encounter_type_sk') }}

    union all

    select
        'inpatient long term acute care' as encounter_type
      , cast('32' as {{ dbt.type_string() }}) as encounter_type_sk
      , cast('1' as {{ dbt.type_string() }}) as encounter_group_sk
    where not exists (
        select 1
        from {{ ref('semantic_layer__encounter_type_sk') }}
        where encounter_type = 'inpatient long term acute care'
    )
)

select
    encounter_type
  , encounter_type_sk
  , encounter_group_sk
  , cast('{{ var('tuva_last_run') }}' as {{ dbt.type_timestamp() }}) as tuva_last_run
from encounter_types
