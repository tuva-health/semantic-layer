SELECT
    s.encounter_id
  , s.person_id
  , s.data_source
  , s.ed_classification_order
  , s.ed_classification_description
  , cast('{{ var('tuva_last_run') }}' as {{ dbt.type_timestamp() }}) as tuva_last_run
FROM {{ ref('nyu_ed_classification', 'ed_classification__summary') }} as s
