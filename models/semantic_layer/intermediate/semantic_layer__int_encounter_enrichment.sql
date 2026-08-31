select
    e.encounter_id
  , e.encounter_group_sk
  , e.encounter_type_sk
  , e.primary_diagnosis_code_type
  , e.primary_diagnosis_code
  , e.primary_diagnosis_description
  , e.data_source
  , p.primary_provider_id
  , p.specialty
  , ccsr.ccsr_parent_category
  , ccsr.ccsr_category
  , ccsr.ccsr_category_description
from {{ ref('semantic_layer__fact_encounters') }} as e
left join {{ ref('semantic_layer__dim_encounter_provider') }} as p
    on e.encounter_id = p.encounter_id
   and e.data_source = p.data_source
left join {{ ref('ccsr', 'ccsr__dx_vertical_pivot') }} as ccsr
    on e.primary_diagnosis_code = ccsr.code
   and lower(cast(e.primary_diagnosis_code_type as {{ dbt.type_string() }})) = 'icd-10-cm'
   and ccsr.ccsr_category_rank = 1
