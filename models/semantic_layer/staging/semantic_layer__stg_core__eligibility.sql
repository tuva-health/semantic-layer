SELECT DISTINCT
  e.data_source
  , cast('{{ var('tuva_last_run') }}' as {{ dbt.type_timestamp() }}) as tuva_last_run
FROM {{ ref('the_tuva_project', 'core__eligibility') }} as e