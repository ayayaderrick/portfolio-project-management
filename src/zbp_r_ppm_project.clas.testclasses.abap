CLASS ltcl_ppm_project DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.

    CLASS-DATA: environment TYPE REF TO if_osql_test_environment.

    CLASS-METHODS: class_setup.
    CLASS-METHODS: class_teardown.

    METHODS setup.
    METHODS terdown.

    "---------------------------------------------------------------
    " Test data helpers
    "---------------------------------------------------------------
    METHODS create_project
      IMPORTING
        iv_start_date   TYPE zppm_start_date DEFAULT '20260101'
        iv_end_date     TYPE zppm_end_date DEFAULT '20261231'
      EXPORTING
        ev_project_uuid TYPE sysuuid_x16.

ENDCLASS.


CLASS ltcl_ppm_project IMPLEMENTATION.

  METHOD class_setup.
    environment = cl_osql_test_environment=>create(
        i_dependency_list = VALUE #(
            ( 'ZPPM_PROJECT_A' )
            ( 'ZPPM_PROJECT_D' )
            ( 'ZPPM_MILESTONE_A' )
            ( 'ZPPM_MILESTOME_D' )
            ( 'ZPPM_TASK_A' )
            ( 'ZPPM_TASK_D' )
         )
     ).
  ENDMETHOD.

  METHOD class_teardown.
    environment->destroy(  ).
  ENDMETHOD.

  METHOD setup.
    environment->clear_doubles(  ).
  ENDMETHOD.

  METHOD terdown.
    ROLLBACK ENTITIES.
  ENDMETHOD.

  "=====================================================================
  " Helpers
  "=====================================================================
  METHOD create_project.
    MODIFY ENTITIES OF zr_ppm_project IN LOCAL MODE
    ENTITY Project
    CREATE FIELDS ( ProjectName Description StartDate EndDate )
    WITH VALUE #( ( %cid = 'PROJ1'
                    ProjectName = 'Test Project'
                    Description = 'Created by ABAP Unit'
                    StartDate   = iv_start_date
                    EndDate     = iv_end_date ) )
    MAPPED   DATA(ls_mapped)
    FAILED DATA(failed)
    REPORTED DATA(reported).

    IF line_exists( ls_mapped-project[ %cid = 'PROJ1' ] ).
      ev_project_uuid = ls_mapped-project[ %cid = 'PROJ1' ]-ProjectUUID.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
