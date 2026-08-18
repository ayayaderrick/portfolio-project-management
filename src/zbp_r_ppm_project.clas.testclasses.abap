CLASS ltcl_ppm_project DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    TYPES:
      ty_failed_early   TYPE RESPONSE FOR FAILED EARLY zr_ppm_project,
      ty_reported_early TYPE RESPONSE FOR REPORTED EARLY zr_ppm_project.

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
        ev_project_uuid TYPE sysuuid_x16
        et_failed            TYPE ty_failed_early
        et_reported          TYPE ty_reported_early.

    METHODS create_project_with_milestone
      IMPORTING
        iv_project_start  TYPE zppm_start_date DEFAULT '20260101'
        iv_project_end    TYPE zppm_end_date DEFAULT '20261231'
        iv_ms_sequence_no TYPE zppm_sequence_no DEFAULT 1
        iv_ms_due_date    TYPE zppm_due_date DEFAULT '20260615'
      EXPORTING
        ev_project_uuid   TYPE sysuuid_x16
        ev_milestone_uuid TYPE sysuuid_x16
        et_failed            TYPE ty_failed_early
        et_reported          TYPE ty_reported_early.

    METHODS create_full_hierarchy
      IMPORTING
        iv_project_start    TYPE zppm_start_date DEFAULT '20260101'
        iv_project_end      TYPE zppm_end_date DEFAULT '20261231'
        iv_ms_due_date      TYPE zppm_due_date DEFAULT '20260615'
        iv_task_due_date    TYPE zppm_due_date DEFAULT '20260601'
        iv_task_status      TYPE zppm_task_status DEFAULT zif_ppm_constants=>task_status-open
        iv_task_assigned_to TYPE zppm_assigned_to OPTIONAL
      EXPORTING
        ev_project_uuid     TYPE sysuuid_x16
        ev_milestone_uuid   TYPE sysuuid_x16
        ev_task_uuid        TYPE sysuuid_x16
        et_failed            TYPE ty_failed_early
        et_reported          TYPE ty_reported_early.

    "---------------------------------------------------------------
    " Project level
    "---------------------------------------------------------------
    METHODS project_id_is_assigned FOR TESTING.
    METHODS project_ids_are_unique FOR TESTING.

    METHODS dates_end_before_start_fails FOR TESTING.
    METHODS dates_valid_range_succeeds FOR TESTING.

    METHODS start_project_from_new_ok FOR TESTING.
    METHODS start_project_twice_fails FOR TESTING.

    METHODS put_on_hold_from_new_ok FOR TESTING.
    METHODS put_on_hold_after_cancel_fails FOR TESTING.

    METHODS resume_from_on_hold_ok FOR TESTING.
    METHODS resume_from_new_fails FOR TESTING.

    METHODS cancel_from_new_ok FOR TESTING.
    METHODS cancel_twice_fails FOR TESTING.

    METHODS project_features_new_status FOR TESTING.

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
      FAILED   et_failed
      REPORTED et_reported.

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
      FAILED   et_failed
      REPORTED et_reported.

    IF line_exists( ls_mapped-project[ %cid = 'PROJ1' ] ).
      ev_project_uuid = ls_mapped-project[ %cid = 'PROJ1' ]-ProjectUUID.
    ENDIF.
    IF line_exists( ls_mapped-milestone[ %cid = 'MS1' ] ).
      ev_milestone_uuid = ls_mapped-milestone[ %cid = 'MS1' ]-MilestoneUuid.
    ENDIF.
  ENDMETHOD.

  METHOD create_full_hierarchy.
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
                              SequenceNo    = 1
                              DueDate       = iv_ms_due_date ) ) ) )
      ENTITY Milestone
        CREATE BY \_Task
        FIELDS ( TaskName Description Priority DueDate Status AssignedTo )
        WITH VALUE #( ( %cid_ref = 'MS1'
                         %target  = VALUE #(
                            ( %cid        = 'TASK1'
                              TaskName    = 'Task 1'
                              Description = 'Created by ABAP Unit'
                              Priority    = zif_ppm_constants=>priority-medium
                              DueDate     = iv_task_due_date
                              Status      = iv_task_status
                              AssignedTo  = iv_task_assigned_to ) ) ) )
      MAPPED   DATA(ls_mapped)
      FAILED   et_failed
      REPORTED et_reported.

    IF line_exists( ls_mapped-project[ %cid = 'PROJ1' ] ).
      ev_project_uuid = ls_mapped-project[ %cid = 'PROJ1' ]-ProjectUUID.
    ENDIF.
    IF line_exists( ls_mapped-milestone[ %cid = 'MS1' ] ).
      ev_milestone_uuid = ls_mapped-milestone[ %cid = 'MS1' ]-MilestoneUuid.
    ENDIF.
    IF line_exists( ls_mapped-task[ %cid = 'TASK1' ] ).
      ev_task_uuid = ls_mapped-task[ %cid = 'TASK1' ]-TaskUuid.
    ENDIF.
  ENDMETHOD.


  "=====================================================================
  " Project: numbering (setProjectId)
  "=====================================================================
  METHOD project_id_is_assigned.

    create_project(
      IMPORTING
        ev_project_uuid = DATA(lv_project_uuid)
        et_failed       = DATA(lt_failed)
        et_reported     = DATA(lt_reported) ).

    cl_abap_unit_assert=>assert_initial( lt_failed-project ).

    READ ENTITIES OF zr_ppm_project IN LOCAL MODE
      ENTITY Project
        FIELDS ( ProjectID )
        WITH VALUE #( ( ProjectUUID = lv_project_uuid ) )
      RESULT DATA(lt_projects).

    cl_abap_unit_assert=>assert_not_initial(
        act = lt_projects[ 1 ]-ProjectID
        msg = |ProjectID should be assigned by the number range on create| ).

  ENDMETHOD.

  METHOD project_ids_are_unique.

    create_project( IMPORTING ev_project_uuid = DATA(lv_uuid_1) ).

    MODIFY ENTITIES OF zr_ppm_project IN LOCAL MODE
    ENTITY Project
    CREATE FIELDS ( ProjectName Description StartDate EndDate )
    WITH VALUE #( ( %cid = 'PROJ2'
                    ProjectName = 'Second Project'
                    Description = 'Created by ABAP Unit'
                    StartDate   = '20260101'
                    EndDate     = '20261231' ) )
    MAPPED DATA(ls_mapped)
    FAILED DATA(lt_failed).

    cl_abap_unit_assert=>assert_initial( lt_failed-project ).

    DATA(lv_uuid_2) = ls_mapped-project[ %cid = 'PROJ2' ]-ProjectUUID.

    READ ENTITIES OF zr_ppm_project IN LOCAL MODE
    ENTITY Project
    FIELDS ( ProjectID )
    WITH VALUE #( ( ProjectUUID = lv_uuid_1 )
                  ( ProjectUUID = lv_uuid_2 ) )
    RESULT DATA(lt_projects).

    cl_abap_unit_assert=>assert_equals( act = lines( lt_projects ) exp = 2 ).
    cl_abap_unit_assert=>assert_differs(
        act = lt_projects[ ProjectUUID = lv_uuid_1 ]-ProjectID
        exp = lt_projects[ ProjectUUID = lv_uuid_2 ]-ProjectID ).

  ENDMETHOD.

  "=====================================================================
  " Project: validateProjectDates
  "=====================================================================
  METHOD dates_end_before_start_fails.

    create_project(
      EXPORTING
        iv_start_date   = '20260601'
        iv_end_date     = '20260101'
      IMPORTING
        et_failed       = DATA(lt_failed)
        et_reported     = DATA(lt_reported) ).

    cl_abap_unit_assert=>assert_not_initial(
        act = lt_failed-project
        msg = |End date before start date must be rejected| ).
    cl_abap_unit_assert=>assert_not_initial( lt_reported-project ).

  ENDMETHOD.

  METHOD dates_valid_range_succeeds.

    create_project(
      EXPORTING
        iv_start_date   = '20260101'
        iv_end_date     = '20261231'
      IMPORTING
        et_failed       = DATA(lt_failed) ).

    cl_abap_unit_assert=>assert_initial( lt_failed-project ).

  ENDMETHOD.

  "===========================================================================
  " Project Actions: startProject / putOnHold / resumeProject / cancelProject
  "===========================================================================
  METHOD start_project_from_new_ok.

    create_project( IMPORTING ev_project_uuid = DATA(lv_uuid) ).

    MODIFY ENTITIES OF zr_ppm_project IN LOCAL MODE
    ENTITY Project
    EXECUTE startProject
    FROM VALUE #( ( %tky-ProjectUUID = lv_uuid ) )
    RESULT DATA(lt_result)
    FAILED DATA(lt_failed).

    cl_abap_unit_assert=>assert_initial( lt_failed-project ).
    cl_abap_unit_assert=>assert_equals(
        act = lt_result[ 1 ]-%param-Status
        exp = zif_ppm_constants=>project_status-in_progress ).

  ENDMETHOD.

  METHOD start_project_twice_fails.

    create_project( IMPORTING ev_project_uuid = DATA(lv_uuid) ).

    MODIFY ENTITIES OF zr_ppm_project IN LOCAL MODE
    ENTITY Project
    EXECUTE startProject
    FROM VALUE #( ( %tky-ProjectUUID = lv_uuid ) )
    FAILED DATA(lt_failed_1).

    cl_abap_unit_assert=>assert_initial( lt_failed_1-project ).

    MODIFY ENTITIES OF zr_ppm_project IN LOCAL MODE
    ENTITY Project
    EXECUTE startProject
    FROM VALUE #( ( %tky-ProjectUUID = lv_uuid ) )
    FAILED DATA(lt_failed_2).

    cl_abap_unit_assert=>assert_not_initial(
        act = lt_failed_2-project
        msg = |Starting a project that is already IN_PROGRESS must fail| ).

  ENDMETHOD.

  METHOD put_on_hold_after_cancel_fails.

    create_project( IMPORTING ev_project_uuid = DATA(lv_uuid) ).

    MODIFY ENTITIES OF zr_ppm_project IN LOCAL MODE
    ENTITY Project
    EXECUTE cancelProject
    FROM VALUE #( ( %tky-ProjectUUID = lv_uuid ) )
    FAILED DATA(lt_failed_cancel).

    cl_abap_unit_assert=>assert_initial( lt_failed_cancel-project ).

    MODIFY ENTITIES OF zr_ppm_project IN LOCAL MODE
    ENTITY Project
    EXECUTE putOnHold
    FROM VALUE #( ( %tky-ProjectUUID = lv_uuid ) )
    FAILED DATA(lt_failed_hold).

    cl_abap_unit_assert=>assert_not_initial(
        act = lt_failed_hold-project
        msg = |A cancelled project cannot be put on hold| ).

  ENDMETHOD.

  METHOD put_on_hold_from_new_ok.

    create_project( IMPORTING ev_project_uuid = DATA(lv_uuid) ).

    MODIFY ENTITIES OF zr_ppm_project IN LOCAL MODE
    ENTITY Project
    EXECUTE putOnHold
    FROM VALUE #( ( %tky-ProjectUUID = lv_uuid ) )
    RESULT DATA(lt_result)
    FAILED DATA(lt_failed).

    cl_abap_unit_assert=>assert_initial( lt_failed-project ).
    cl_abap_unit_assert=>assert_equals(
        act = lt_result[ 1 ]-%param-Status
        exp = zif_ppm_constants=>project_status-on_hold ).

  ENDMETHOD.

  METHOD resume_from_on_hold_ok.

    create_project( IMPORTING ev_project_uuid = DATA(lv_uuid) ).

    MODIFY ENTITIES OF zr_ppm_project IN LOCAL MODE
      ENTITY Project EXECUTE putOnHold
        FROM VALUE #( ( %tky-ProjectUUID = lv_uuid ) )
      FAILED DATA(lt_failed_hold).
    cl_abap_unit_assert=>assert_initial( lt_failed_hold-project ).

    MODIFY ENTITIES OF zr_ppm_project IN LOCAL MODE
      ENTITY Project EXECUTE resumeProject
        FROM VALUE #( ( %tky-ProjectUUID = lv_uuid ) )
      RESULT DATA(lt_result)
      FAILED DATA(lt_failed_resume).

    cl_abap_unit_assert=>assert_initial( lt_failed_resume-project ).
    cl_abap_unit_assert=>assert_equals(
        act = lt_result[ 1 ]-%param-Status
        exp = zif_ppm_constants=>project_status-in_progress ).

  ENDMETHOD.

  METHOD resume_from_new_fails.

    create_project( IMPORTING ev_project_uuid = DATA(lv_uuid) ).

    MODIFY ENTITIES OF zr_ppm_project IN LOCAL MODE
    ENTITY Project
    EXECUTE resumeProject
    FROM VALUE #( ( %tky-ProjectUUID = lv_uuid ) )
    FAILED DATA(lt_failed).

    cl_abap_unit_assert=>assert_not_initial(
        act = lt_failed-project
        msg = |Only ON_HOLD projects can be resumed| ).

  ENDMETHOD.

  METHOD cancel_from_new_ok.

    create_project( IMPORTING ev_project_uuid = DATA(lv_uuid) ).

    MODIFY ENTITIES OF zr_ppm_project IN LOCAL MODE
    ENTITY Project
    EXECUTE cancelProject
    FROM VALUE #( ( %tky-ProjectUUID = lv_uuid ) )
    RESULT DATA(lt_result)
    FAILED DATA(lt_failed).

    cl_abap_unit_assert=>assert_initial( lt_failed-project ).
    cl_abap_unit_assert=>assert_equals(
        act = lt_result[ 1 ]-%param-Status
        exp = zif_ppm_constants=>project_status-cancelled ).

  ENDMETHOD.

  METHOD cancel_twice_fails.

  ENDMETHOD.

  METHOD project_features_new_status.

  ENDMETHOD.







ENDCLASS.
