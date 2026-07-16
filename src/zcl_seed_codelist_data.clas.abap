CLASS zcl_seed_codelist_data DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES if_oo_adt_classrun .
    INTERFACES zif_ppm_constants.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_seed_codelist_data IMPLEMENTATION.


  METHOD if_oo_adt_classrun~main.

    DATA lt_codelist TYPE TABLE OF zppm_codelist.
    DATA lt_texts TYPE TABLE OF zppm_codelist_t.

    GET TIME STAMP FIELD DATA(lv_timestamp).

    DELETE FROM zppm_codelist.
    DELETE FROM zppm_codelist_t.

    DATA(uuid1) = xco_cp=>uuid(  )->value.
    DATA(uuid2) = xco_cp=>uuid(  )->value.
    DATA(uuid3) = xco_cp=>uuid(  )->value.
    DATA(uuid4) = xco_cp=>uuid(  )->value.
    DATA(uuid5) = xco_cp=>uuid(  )->value.
    DATA(uuid6) = xco_cp=>uuid(  )->value.
    DATA(uuid7) = xco_cp=>uuid(  )->value.
    DATA(uuid8) = xco_cp=>uuid(  )->value.
    DATA(uuid9) = xco_cp=>uuid(  )->value.
    DATA(uuid10) = xco_cp=>uuid(  )->value.
    DATA(uuid11) = xco_cp=>uuid(  )->value.
    DATA(uuid12) = xco_cp=>uuid(  )->value.
    DATA(uuid13) = xco_cp=>uuid(  )->value.
    DATA(uuid14) = xco_cp=>uuid(  )->value.
    DATA(uuid15) = xco_cp=>uuid(  )->value.
    DATA(uuid16) = xco_cp=>uuid(  )->value.

    lt_codelist = VALUE #(
        ( codelist_uuid = uuid1 code_type = 'PROJECT_STATUS' code = zif_ppm_constants~project_status-new
          active = abap_true sort_order = 10 created_by = 'SEED_USER' created_at = lv_timestamp
          local_last_changed_by = 'SEED_USER' local_last_changed_at = lv_timestamp last_changed_at = lv_timestamp )
        ( codelist_uuid = uuid2 code_type = 'PROJECT_STATUS' code = zif_ppm_constants~project_status-in_progress
          active = abap_true sort_order = 20 created_by = 'SEED_USER' created_at = lv_timestamp
          local_last_changed_by = 'SEED_USER' local_last_changed_at = lv_timestamp last_changed_at = lv_timestamp )
        ( codelist_uuid = uuid3 code_type = 'PROJECT_STATUS' code = zif_ppm_constants~project_status-on_hold
          active = abap_true sort_order = 30 created_by = 'SEED_USER' created_at = lv_timestamp
          local_last_changed_by = 'SEED_USER' local_last_changed_at = lv_timestamp last_changed_at = lv_timestamp )
        ( codelist_uuid = uuid4 code_type = 'PROJECT_STATUS' code = zif_ppm_constants~project_status-completed
          active = abap_true sort_order = 40 created_by = 'SEED_USER' created_at = lv_timestamp
          local_last_changed_by = 'SEED_USER' local_last_changed_at = lv_timestamp last_changed_at = lv_timestamp )
        ( codelist_uuid = uuid5 code_type = 'PROJECT_STATUS' code = zif_ppm_constants~project_status-cancelled
          active = abap_true sort_order = 50 created_by = 'SEED_USER' created_at = lv_timestamp
          local_last_changed_by = 'SEED_USER' local_last_changed_at = lv_timestamp last_changed_at = lv_timestamp )

        ( codelist_uuid = uuid6 code_type = 'MILESTONE_STATUS' code = zif_ppm_constants~milestone_status-new
          active = abap_true sort_order = 10 created_by = 'SEED_USER' created_at = lv_timestamp
          local_last_changed_by = 'SEED_USER' local_last_changed_at = lv_timestamp last_changed_at = lv_timestamp )
        ( codelist_uuid = uuid7 code_type = 'MILESTONE_STATUS' code = zif_ppm_constants~milestone_status-in_progress
          active = abap_true sort_order = 20 created_by = 'SEED_USER' created_at = lv_timestamp
          local_last_changed_by = 'SEED_USER' local_last_changed_at = lv_timestamp last_changed_at = lv_timestamp )
        ( codelist_uuid = uuid8 code_type = 'MILESTONE_STATUS' code = zif_ppm_constants~milestone_status-completed
          active = abap_true sort_order = 30 created_by = 'SEED_USER' created_at = lv_timestamp
          local_last_changed_by = 'SEED_USER' local_last_changed_at = lv_timestamp last_changed_at = lv_timestamp )

        ( codelist_uuid = uuid9 code_type = 'TASK_STATUS' code = zif_ppm_constants~task_status-open
          active = abap_true sort_order = 10 created_by = 'SEED_USER' created_at = lv_timestamp
          local_last_changed_by = 'SEED_USER' local_last_changed_at = lv_timestamp last_changed_at = lv_timestamp )
        ( codelist_uuid = uuid10 code_type = 'TASK_STATUS' code = zif_ppm_constants~task_status-in_progress
          active = abap_true sort_order = 20 created_by = 'SEED_USER' created_at = lv_timestamp
          local_last_changed_by = 'SEED_USER' local_last_changed_at = lv_timestamp last_changed_at = lv_timestamp )
        ( codelist_uuid = uuid11 code_type = 'TASK_STATUS' code = zif_ppm_constants~task_status-blocked
          active = abap_true sort_order = 30 created_by = 'SEED_USER' created_at = lv_timestamp
          local_last_changed_by = 'SEED_USER' local_last_changed_at = lv_timestamp last_changed_at = lv_timestamp )
        ( codelist_uuid = uuid12 code_type = 'TASK_STATUS' code = zif_ppm_constants~task_status-done
          active = abap_true sort_order = 40 created_by = 'SEED_USER' created_at = lv_timestamp
          local_last_changed_by = 'SEED_USER' local_last_changed_at = lv_timestamp last_changed_at = lv_timestamp )

        ( codelist_uuid = uuid13 code_type = 'PRIORITY' code = zif_ppm_constants~priority-low
          active = abap_true sort_order = 10 created_by = 'SEED_USER' created_at = lv_timestamp
          local_last_changed_by = 'SEED_USER' local_last_changed_at = lv_timestamp last_changed_at = lv_timestamp )
        ( codelist_uuid = uuid14 code_type = 'PRIORITY' code = zif_ppm_constants~priority-medium
          active = abap_true sort_order = 20 created_by = 'SEED_USER' created_at = lv_timestamp
          local_last_changed_by = 'SEED_USER' local_last_changed_at = lv_timestamp last_changed_at = lv_timestamp )
        ( codelist_uuid = uuid15 code_type = 'PRIORITY' code = zif_ppm_constants~priority-high
          active = abap_true sort_order = 30 created_by = 'SEED_USER' created_at = lv_timestamp
          local_last_changed_by = 'SEED_USER' local_last_changed_at = lv_timestamp last_changed_at = lv_timestamp )
        ( codelist_uuid = uuid16 code_type = 'PRIORITY' code = zif_ppm_constants~priority-critical
          active = abap_true sort_order = 40 created_by = 'SEED_USER' created_at = lv_timestamp
          local_last_changed_by = 'SEED_USER' local_last_changed_at = lv_timestamp last_changed_at = lv_timestamp )
     ).

    lt_texts = VALUE #(
        ( codelist_uuid = uuid1 language = 'E' description = 'New' )
        ( codelist_uuid = uuid2 language = 'E' description = 'In Progress' )
        ( codelist_uuid = uuid3 language = 'E' description = 'On Hold' )
        ( codelist_uuid = uuid4 language = 'E' description = 'Completed' )
        ( codelist_uuid = uuid5 language = 'E' description = 'Cancelled' )

        ( codelist_uuid = uuid6 language = 'E' description = 'New' )
        ( codelist_uuid = uuid7 language = 'E' description = 'In Progress' )
        ( codelist_uuid = uuid8 language = 'E' description = 'Completed' )

        ( codelist_uuid = uuid9 language = 'E' description = 'Open' )
        ( codelist_uuid = uuid10 language = 'E' description = 'In Progress' )
        ( codelist_uuid = uuid11 language = 'E' description = 'Blocked' )
        ( codelist_uuid = uuid12 language = 'E' description = 'Done' )

        ( codelist_uuid = uuid13 language = 'E' description = 'Low' )
        ( codelist_uuid = uuid14 language = 'E' description = 'Medium' )
        ( codelist_uuid = uuid15 language = 'E' description = 'High' )
        ( codelist_uuid = uuid16 language = 'E' description = 'Critical' )
     ).

    INSERT zppm_codelist FROM TABLE @lt_codelist.
    INSERT zppm_codelist_t FROM TABLE @lt_texts.

    out->write( 'Database tables seeded successfully.' ).

  ENDMETHOD.
ENDCLASS.
