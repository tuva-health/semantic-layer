select
    encounter_type
  , encounter_type_sk
  , encounter_group_sk
  , cast('{{ var('tuva_last_run') }}' as {{ dbt.type_timestamp() }}) as tuva_last_run
from {{ ref('semantic_layer__encounter_type_sk') }}
