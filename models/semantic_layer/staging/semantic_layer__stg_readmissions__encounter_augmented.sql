SELECT
  ea.*
FROM {{ ref('quality_measures', 'readmissions__encounter_augmented') }} as ea