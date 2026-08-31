WITH monthly_patient_costs AS (
    SELECT
        person_id
      , year_month
      , member_id
      , payer
      , {{ the_tuva_project.quote_column('plan') }}
      , data_source
      , inpatient_paid
      , outpatient_paid
      , office_based_paid
      , ancillary_paid
      , other_paid
      , pharmacy_paid
      , acute_inpatient_paid
      , ambulance_paid
      , ambulatory_surgery_center_paid
      , dialysis_paid
      , durable_medical_equipment_paid
      , emergency_department_paid
      , home_health_paid
      , inpatient_hospice_paid
      , inpatient_psychiatric_paid
      , inpatient_rehabilitation_paid
      , lab_paid
      , observation_paid
      , office_based_other_paid
      , office_based_pt_ot_st_paid
      , office_based_radiology_paid
      , office_based_surgery_paid
      , office_based_visit_paid
      , outpatient_hospice_paid
      , outpatient_hospital_or_clinic_paid
      , outpatient_pt_ot_st_paid
      , outpatient_psychiatric_paid
      , outpatient_radiology_paid
      , outpatient_rehabilitation_paid
      , outpatient_surgery_paid
      , skilled_nursing_paid
      , telehealth_visit_paid
      , urgent_care_paid
      , inpatient_allowed
      , outpatient_allowed
      , office_based_allowed
      , ancillary_allowed
      , other_allowed
      , pharmacy_allowed
      , acute_inpatient_allowed
      , ambulance_allowed
      , ambulatory_surgery_center_allowed
      , dialysis_allowed
      , durable_medical_equipment_allowed
      , emergency_department_allowed
      , home_health_allowed
      , inpatient_hospice_allowed
      , inpatient_psychiatric_allowed
      , inpatient_rehabilitation_allowed
      , lab_allowed
      , observation_allowed
      , office_based_other_allowed
      , office_based_pt_ot_st_allowed
      , office_based_radiology_allowed
      , office_based_surgery_allowed
      , office_based_visit_allowed
      , outpatient_hospice_allowed
      , outpatient_hospital_or_clinic_allowed
      , outpatient_pt_ot_st_allowed
      , outpatient_psychiatric_allowed
      , outpatient_radiology_allowed
      , outpatient_rehabilitation_allowed
      , outpatient_surgery_allowed
      , skilled_nursing_allowed
      , telehealth_visit_allowed
      , urgent_care_allowed
      , total_paid
      , medical_paid
      , total_allowed
      , medical_allowed
      , tuva_last_run
    FROM {{ ref('semantic_layer__stg_core__cost') }}
),

combined_data_cte AS (
    SELECT
        mm.person_id
      , mm.member_id
      , mm.member_month_id
      , mm.data_source
      , mm.payer
      , mm.{{ the_tuva_project.quote_column('plan') }}
      , {{ the_tuva_project.concat_custom(["mm.person_id", "'|'", "mm.data_source"]) }} AS patient_source_key
      , {{ the_tuva_project.concat_custom(["mm.person_id", "'|'", "mm.year_month"]) }} AS member_month_sk
      , mm.year_month
      , mm.year_nbr
      , 1 AS member_months_value
      , mmr.risk_model_code
      , mmr.normalized_risk_score
      , mmr.population_normalized_risk_score
      , pc.inpatient_paid
      , pc.outpatient_paid
      , pc.office_based_paid
      , pc.ancillary_paid
      , pc.other_paid
      , pc.pharmacy_paid
      , pc.acute_inpatient_paid
      , pc.ambulance_paid
      , pc.ambulatory_surgery_center_paid
      , pc.dialysis_paid
      , pc.durable_medical_equipment_paid
      , pc.emergency_department_paid
      , pc.home_health_paid
      , pc.inpatient_hospice_paid
      , pc.inpatient_psychiatric_paid
      , pc.inpatient_rehabilitation_paid
      , pc.lab_paid
      , pc.observation_paid
      , pc.office_based_other_paid
      , pc.office_based_pt_ot_st_paid
      , pc.office_based_radiology_paid
      , pc.office_based_surgery_paid
      , pc.office_based_visit_paid
      , pc.outpatient_hospice_paid
      , pc.outpatient_hospital_or_clinic_paid
      , pc.outpatient_pt_ot_st_paid
      , pc.outpatient_psychiatric_paid
      , pc.outpatient_radiology_paid
      , pc.outpatient_rehabilitation_paid
      , pc.outpatient_surgery_paid
      , pc.skilled_nursing_paid
      , pc.telehealth_visit_paid
      , pc.urgent_care_paid
      , pc.inpatient_allowed
      , pc.outpatient_allowed
      , pc.office_based_allowed
      , pc.ancillary_allowed
      , pc.other_allowed
      , pc.pharmacy_allowed
      , pc.acute_inpatient_allowed
      , pc.ambulance_allowed
      , pc.ambulatory_surgery_center_allowed
      , pc.dialysis_allowed
      , pc.durable_medical_equipment_allowed
      , pc.emergency_department_allowed
      , pc.home_health_allowed
      , pc.inpatient_hospice_allowed
      , pc.inpatient_psychiatric_allowed
      , pc.inpatient_rehabilitation_allowed
      , pc.lab_allowed
      , pc.observation_allowed
      , pc.office_based_other_allowed
      , pc.office_based_pt_ot_st_allowed
      , pc.office_based_radiology_allowed
      , pc.office_based_surgery_allowed
      , pc.office_based_visit_allowed
      , pc.outpatient_hospice_allowed
      , pc.outpatient_hospital_or_clinic_allowed
      , pc.outpatient_pt_ot_st_allowed
      , pc.outpatient_psychiatric_allowed
      , pc.outpatient_radiology_allowed
      , pc.outpatient_rehabilitation_allowed
      , pc.outpatient_surgery_allowed
      , pc.skilled_nursing_allowed
      , pc.telehealth_visit_allowed
      , pc.urgent_care_allowed
      , pc.total_paid
      , pc.medical_paid
      , pc.total_allowed
      , pc.medical_allowed
      , mm.tuva_last_run
    FROM {{ ref('semantic_layer__stg_core__member_month') }} mm
    LEFT JOIN {{ ref('semantic_layer__int_member_month_risk') }} as mmr
        ON mm.member_month_id = mmr.member_month_id
       AND mm.data_source = mmr.data_source
    LEFT JOIN monthly_patient_costs pc
        ON mm.person_id = pc.person_id
       AND mm.member_id = pc.member_id
       AND mm.year_month = pc.year_month
       AND (
            mm.payer = pc.payer
            OR (mm.payer IS NULL AND pc.payer IS NULL)
       )
       AND (
            mm.{{ the_tuva_project.quote_column('plan') }} = pc.{{ the_tuva_project.quote_column('plan') }}
            OR (
                mm.{{ the_tuva_project.quote_column('plan') }} IS NULL
                AND pc.{{ the_tuva_project.quote_column('plan') }} IS NULL
            )
       )
       AND mm.data_source = pc.data_source
)

SELECT
    cd.person_id
  , cd.member_id
  , cd.member_month_id
  , cd.year_nbr
  , cd.year_month
  , cd.member_month_sk
  , cd.member_months_value AS member_months
  , SUM(cd.member_months_value) OVER (
      PARTITION BY
          cd.person_id
        , cd.member_id
        , cd.payer
        , cd.{{ the_tuva_project.quote_column('plan') }}
        , cd.data_source
        , cd.year_nbr
    ) AS total_year_months
  , CASE
      WHEN SUM(cd.member_months_value) OVER (
        PARTITION BY cd.person_id, cd.member_id, cd.payer,
          cd.{{ the_tuva_project.quote_column('plan') }}, cd.data_source, cd.year_nbr
      ) > 0
      THEN CAST(cd.member_months_value AS {{ dbt.type_numeric() }}) / SUM(cd.member_months_value) OVER (
        PARTITION BY cd.person_id, cd.member_id, cd.payer,
          cd.{{ the_tuva_project.quote_column('plan') }}, cd.data_source, cd.year_nbr
      )
      ELSE CAST(0 AS {{ dbt.type_numeric() }})
    END AS MonthAllocationFactor
  , cd.data_source
  , cd.payer
  , cd.{{ the_tuva_project.quote_column('plan') }}
  , cd.patient_source_key
  , cd.risk_model_code
  , cd.normalized_risk_score
  , cd.population_normalized_risk_score
  , cd.inpatient_paid
  , cd.outpatient_paid
  , cd.office_based_paid
  , cd.ancillary_paid
  , cd.other_paid
  , cd.pharmacy_paid
  , cd.acute_inpatient_paid
  , cd.ambulance_paid
  , cd.ambulatory_surgery_center_paid
  , cd.dialysis_paid
  , cd.durable_medical_equipment_paid
  , cd.emergency_department_paid
  , cd.home_health_paid
  , cd.inpatient_hospice_paid
  , cd.inpatient_psychiatric_paid
  , cd.inpatient_rehabilitation_paid
  , cd.lab_paid
  , cd.observation_paid
  , cd.office_based_other_paid
  , cd.office_based_pt_ot_st_paid
  , cd.office_based_radiology_paid
  , cd.office_based_surgery_paid
  , cd.office_based_visit_paid
  , cd.outpatient_hospice_paid
  , cd.outpatient_hospital_or_clinic_paid
  , cd.outpatient_pt_ot_st_paid
  , cd.outpatient_psychiatric_paid
  , cd.outpatient_radiology_paid
  , cd.outpatient_rehabilitation_paid
  , cd.outpatient_surgery_paid
  , cd.skilled_nursing_paid
  , cd.telehealth_visit_paid
  , cd.urgent_care_paid
  , cd.inpatient_allowed
  , cd.outpatient_allowed
  , cd.office_based_allowed
  , cd.ancillary_allowed
  , cd.other_allowed
  , cd.pharmacy_allowed
  , cd.acute_inpatient_allowed
  , cd.ambulance_allowed
  , cd.ambulatory_surgery_center_allowed
  , cd.dialysis_allowed
  , cd.durable_medical_equipment_allowed
  , cd.emergency_department_allowed
  , cd.home_health_allowed
  , cd.inpatient_hospice_allowed
  , cd.inpatient_psychiatric_allowed
  , cd.inpatient_rehabilitation_allowed
  , cd.lab_allowed
  , cd.observation_allowed
  , cd.office_based_other_allowed
  , cd.office_based_pt_ot_st_allowed
  , cd.office_based_radiology_allowed
  , cd.office_based_surgery_allowed
  , cd.office_based_visit_allowed
  , cd.outpatient_hospice_allowed
  , cd.outpatient_hospital_or_clinic_allowed
  , cd.outpatient_pt_ot_st_allowed
  , cd.outpatient_psychiatric_allowed
  , cd.outpatient_radiology_allowed
  , cd.outpatient_rehabilitation_allowed
  , cd.outpatient_surgery_allowed
  , cd.skilled_nursing_allowed
  , cd.telehealth_visit_allowed
  , cd.urgent_care_allowed
  , cd.total_paid
  , cd.medical_paid
  , cd.total_allowed
  , cd.medical_allowed
  , cd.tuva_last_run
FROM combined_data_cte AS cd
