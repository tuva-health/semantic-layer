SELECT
    p.pqi_number
  , p.pqi_name
  , p.encounter_id
  , p.data_source
  , cast('{{ var('tuva_last_run') }}' as {{ dbt.type_timestamp() }}) as tuva_last_run
FROM {{ ref('ahrq_quality_indicators', 'ahrq_quality_indicators__pqi_summary') }} as p
