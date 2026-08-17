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

    METHODS create_project_with_milestone
      IMPORTING
        iv_project_start     TYPE zppm_start_date DEFAULT '20260101'
        iv_project_end       TYPE zppm_end_date DEFAULT '20261231'
        iv_ms_sequence_no    TYPE zppm_sequence_no DEFAULT 1
        iv_ms_due_date       TYPE zppm_due_date DEFAULT '20260615'
      EXPORTING
        ev_project_uuid      TYPE sysuuid_x16
        ev_milestone_uuid    TYPE sysuuid_x16.

    METHODS create_full_hierarchy
      IMPORTING
        iv_project_start     TYPE zppm_start_date DEFAULT '20260101'
        iv_project_end       TYPE zppm_end_date DEFAULT '20261231'
        iv_ms_due_date       TYPE zppm_due_date DEFAULT '20260615'
        iv_task_due_date     TYPE zppm_due_date DEFAULT '20260601'
        iv_task_status       TYPE zppm_task_status DEFAULT zif_ppm_constants=>task_status-open
        iv_task_assigned_to  TYPE zppm_assigned_to OPTIONAL
      EXPORTING
        ev_project_uuid      TYPE sysuuid_x16
        ev_milestone_uuid    TYPE sysuuid_x16
        ev_task_uuid         TYPE sysuuid_x16.

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

  METHOD create_project_with_milestone.
     MODIFY ENTITIES OF zr_ppm_project IN LOCAL MODE
      ENTITY Project
        CREATE FIELDS ( ProjectName Description StartDate EndDate )
        WITH VALUE #( ( %cid = 'PROJ1'
                         ProjectName = 'Test Project'
                         Description = 'Created by ABAP Unit'
                         StartDate   = iv_project_start
                         EndDate     = iv_project_end ) )
      ENTITY Project
        CREATE BY \_Milestone
        FIELDS ( MilestoneName Description SequenceNo DueDate )
        WITH VALUE #( ( %cid_ref = 'PROJ1'
                         %target  = VALUE #(
                            ( %cid          = 'MS1'
                              MilestoneName = 'Milestone 1'
                              Description   = 'Created by ABAP Unit'
                              SequenceNo    = iv_ms_sequence_no
                              DueDate       = iv_ms_due_date ) ) ) )
      MAPPED   DATA(ls_mapped)
      FAILED DATA(failed)
      REPORTED DATA(reported).

    IF line_exists( ls_mapped-project[ %cid = 'PROJ1' ] ).
      ev_project_uuid = ls_mapped-project[ %cid = 'PROJ1' ]-ProjectUUID.
    ENDIF.
    IF line_exists( ls_mapped-milestone[ %cid = 'MS1' ] ).
      ev_milestone_uuid = ls_mapped-milestone[ %cid = 'MS1' ]-MilestoneUuid.
    ENDIF.
  ENDMETHOD.

  METHOD create_full_hierarchy.

  ENDMETHOD.

ENDCLASS.
