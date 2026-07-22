CLASS lhc_zr_ppm_project DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS:
      get_global_authorizations FOR GLOBAL AUTHORIZATION
        IMPORTING
        REQUEST requested_authorizations FOR Project
        RESULT result,
      setProjectId FOR DETERMINE ON MODIFY
        IMPORTING keys FOR Project~setProjectId.
ENDCLASS.

CLASS lhc_zr_ppm_project IMPLEMENTATION.
  METHOD get_global_authorizations.
  ENDMETHOD.
  METHOD setProjectId.

    DATA project_id_max TYPE zppm_project_id.
    DATA lt_update TYPE TABLE FOR UPDATE zr_ppm_project.

    READ ENTITIES OF zr_ppm_project IN LOCAL MODE
    ENTITY Project
    FIELDS ( ProjectID )
    WITH CORRESPONDING #( keys )
    RESULT DATA(lt_projects).

    " Ensure Travel ID is not set yet (idempotent)- must be checked when BO is draft-enabled
    DELETE lt_projects WHERE ProjectID IS NOT INITIAL.
    IF lt_projects IS INITIAL. RETURN. ENDIF.

    " Get numbers
    TRY.
        cl_numberrange_runtime=>number_get(
        EXPORTING
          nr_range_nr       = '01'
          object            = 'ZPPM_NR'
          quantity          = CONV #( lines( lt_projects ) )
        IMPORTING
          number            = DATA(number_range_key)
          returncode        = DATA(number_range_return_code)
          returned_quantity = DATA(number_range_returned_quantity)
      ).
      CATCH cx_number_ranges INTO DATA(lx_number_ranges).
        reported-project = VALUE #( FOR project IN  lt_projects (
        %tky = project-%tky
        %msg = new_message_with_text(
                  severity = if_abap_behv_message=>severity-error
                  text     = lx_number_ranges->get_text( )
                  )
        ) ).
        EXIT.
    ENDTRY.

    project_id_max = number_range_key - number_range_returned_quantity.

    lt_update = VALUE #( FOR project IN lt_projects (
        %tky = project-%tky
        ProjectID = |PRJ-{ project_id_max }|
        %control-ProjectID = if_abap_behv=>mk-on
     ) ).

    MODIFY ENTITIES OF zr_ppm_project IN LOCAL MODE
    ENTITY Project
    UPDATE
    FIELDS ( ProjectID )
    WITH lt_update.


  ENDMETHOD.

ENDCLASS.
