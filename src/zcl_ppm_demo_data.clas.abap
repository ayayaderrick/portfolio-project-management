CLASS zcl_ppm_demo_data DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES if_oo_adt_classrun .
  PROTECTED SECTION.

  PRIVATE SECTION.


ENDCLASS.



CLASS zcl_ppm_demo_data IMPLEMENTATION.


  METHOD if_oo_adt_classrun~main.

    " =========================================================
    " FEATURE: PREVENT DUPLICATES (WIPE EXISTING RECORDS FIRST)
    " =========================================================
    " Fetch all current root project identifiers from the database
    SELECT project_uuid FROM zppm_project_a INTO TABLE @DATA(lt_existing_keys).

    IF lt_existing_keys IS NOT INITIAL.
      " Build the EML deletion table mapping target keys
      DATA lt_projects_to_delete TYPE TABLE FOR DELETE zr_ppm_project.
      lt_projects_to_delete = VALUE #( FOR key IN lt_existing_keys ( ProjectUUID = key-project_uuid ) ).

      " Execute cascading delete via RAP
      MODIFY ENTITIES OF zr_ppm_project
      ENTITY Project
      DELETE FROM lt_projects_to_delete
      FAILED DATA(lt_del_failed)
      REPORTED DATA(lt_del_reported).

      IF lt_del_failed IS INITIAL.
        " Save deletions to DB buffer
        COMMIT ENTITIES.
        out->write( |Cleared { lines( lt_projects_to_delete ) } old project hierarchies.| ).
      ELSE.
        out->write( 'Failed to clear old demo data. Aborting execution.' ).
        RETURN.
      ENDIF.

    ENDIF.

    DATA lt_projects TYPE TABLE FOR CREATE zr_ppm_project.
    DATA lt_milestones TYPE TABLE FOR CREATE zr_ppm_project\_Milestone.
    DATA lt_tasks TYPE TABLE FOR CREATE zr_ppm_milestone\_Task.

    " ==========================================
    " LAYER 1: Root / Parent (Project)
    " ==========================================
    APPEND VALUE #(
        %cid = 'Proj_Alpha'
        projectname = 'Project Alpha'
        description = 'Project Portfolio Demo'
        startdate = cl_abap_context_info=>get_system_date(  )
        enddate = cl_abap_context_info=>get_system_date(  ) + 30
        status = zif_ppm_constants=>project_status-in_progress
        %control    = VALUE #( projectname = if_abap_behv=>mk-on
                               description = if_abap_behv=>mk-on
                               startdate = if_abap_behv=>mk-on
                               enddate = if_abap_behv=>mk-on
                               status      = if_abap_behv=>mk-on )
     ) TO lt_projects.

    " ==========================================
    " LAYER 2: First Child (Milestone via Project)
    " ==========================================
    APPEND VALUE #(
        %cid_ref = 'Proj_Alpha'
        %target = VALUE #(
            ( %cid = 'Mstone_Plan'
              milestonename = 'Planning'
              description = 'Planning Phase'
              sequenceno = 10
              duedate = cl_abap_context_info=>get_system_date(  ) + 10
              status = zif_ppm_constants=>milestone_status-in_progress
              %control    = VALUE #( milestonename = if_abap_behv=>mk-on
                               description = if_abap_behv=>mk-on
                               sequenceno = if_abap_behv=>mk-on
                               duedate = if_abap_behv=>mk-on
                               status      = if_abap_behv=>mk-on ) )
            ( %cid = 'Mstone_Dev'
              milestonename = 'Development'
              description = 'Development Phase'
              sequenceno = 20
              duedate = cl_abap_context_info=>get_system_date(  ) + 60
              status = zif_ppm_constants=>milestone_status-in_progress
              %control    = VALUE #( milestonename = if_abap_behv=>mk-on
                               description = if_abap_behv=>mk-on
                               sequenceno = if_abap_behv=>mk-on
                               duedate = if_abap_behv=>mk-on
                               status      = if_abap_behv=>mk-on ) )
         )

     ) TO lt_milestones.

    " ==========================================
    " LAYER 3: Second Child (Task via Milestone)
    " ==========================================
    " Tasks for the Planning Milestone
    APPEND VALUE #(
        %cid_ref = 'Mstone_Plan'
        %target = VALUE #(
            ( %cid = 'Task_Req'
              taskname = 'Requirements'
              description = 'Gather Project Requirements'
              priority = zif_ppm_constants=>priority-high
              status = zif_ppm_constants=>task_status-done
              duedate = cl_abap_context_info=>get_system_date( ) - 20
              %control = VALUE #( taskname = if_abap_behv=>mk-on
                                  description = if_abap_behv=>mk-on
                                  priority = if_abap_behv=>mk-on
                                  status = if_abap_behv=>mk-on
                                  duedate = if_abap_behv=>mk-on ) )
          ( %cid = 'Task_Design'
              taskname = 'Design'
              description = 'Design the Project'
              priority = zif_ppm_constants=>priority-medium
              status = zif_ppm_constants=>task_status-done
              duedate = cl_abap_context_info=>get_system_date( ) - 10
              %control = VALUE #( taskname = if_abap_behv=>mk-on
                                  description = if_abap_behv=>mk-on
                                  priority = if_abap_behv=>mk-on
                                  status = if_abap_behv=>mk-on
                                  duedate = if_abap_behv=>mk-on ) )
          ( %cid = 'Task_Aprv'
              taskname = 'Approval'
              description = 'Approval of Project Design'
              priority = zif_ppm_constants=>priority-high
              status = zif_ppm_constants=>task_status-open
              duedate = cl_abap_context_info=>get_system_date( ) + 10
              %control = VALUE #( taskname = if_abap_behv=>mk-on
                                  description = if_abap_behv=>mk-on
                                  priority = if_abap_behv=>mk-on
                                  status = if_abap_behv=>mk-on
                                  duedate = if_abap_behv=>mk-on ) )
        )
     ) TO lt_tasks.

    " Tasks for the Development Milestone
    APPEND VALUE #(
        %cid_ref = 'Mstone_Dev'
        %target = VALUE #(
            ( %cid = 'Task_Backend'
              taskname = 'Backend'
              description = 'Develop the Backend'
              priority = zif_ppm_constants=>priority-high
              status = zif_ppm_constants=>task_status-done
              duedate = cl_abap_context_info=>get_system_date( ) - 20
              %control = VALUE #( taskname = if_abap_behv=>mk-on
                                  description = if_abap_behv=>mk-on
                                  priority = if_abap_behv=>mk-on
                                  status = if_abap_behv=>mk-on
                                  duedate = if_abap_behv=>mk-on ) )
          ( %cid = 'Task_Frontend'
              taskname = 'Frontend'
              description = 'Develop the Frontend'
              priority = zif_ppm_constants=>priority-medium
              status = zif_ppm_constants=>task_status-open
              duedate = cl_abap_context_info=>get_system_date( ) + 10
              %control = VALUE #( taskname = if_abap_behv=>mk-on
                                  description = if_abap_behv=>mk-on
                                  priority = if_abap_behv=>mk-on
                                  status = if_abap_behv=>mk-on
                                  duedate = if_abap_behv=>mk-on ) )
          ( %cid = 'Task_Test'
              taskname = 'Testing'
              description = 'Testing Phase of the Project'
              priority = zif_ppm_constants=>priority-low
              status = zif_ppm_constants=>task_status-open
              duedate = cl_abap_context_info=>get_system_date( ) + 20
              %control = VALUE #( taskname = if_abap_behv=>mk-on
                                  description = if_abap_behv=>mk-on
                                  priority = if_abap_behv=>mk-on
                                  status = if_abap_behv=>mk-on
                                  duedate = if_abap_behv=>mk-on ) )
        )
     ) TO lt_tasks.

    " ==========================================
    " TRANSACTION PIPELINE: Modify and Persist
    " ==========================================
    MODIFY ENTITIES OF zr_ppm_project
    ENTITY Project
    CREATE FIELDS ( ProjectName Description StartDate EndDate Status ) WITH lt_projects
    CREATE BY \_Milestone FIELDS ( MilestoneName Description SequenceNo DueDate Status ) WITH lt_milestones
    ENTITY Milestone
    CREATE BY \_Task FIELDS ( TaskName Description Priority Status DueDate ) WITH lt_tasks
    MAPPED DATA(lt_mapped)
    FAILED DATA(lt_failed)
    REPORTED DATA(lt_reported).

    " Process the database save if validations pass
    IF lt_failed IS INITIAL.
      COMMIT ENTITIES RESPONSE OF zr_ppm_project
      FAILED DATA(lt_commit_failed)
      REPORTED DATA(lt_commit_reported).

      IF lt_commit_failed IS INITIAL.
        out->write( '3-Layer demo hierarchy seeded successfully!' ).
      ELSE.
        out->write( 'Database save failed at COMMIT phase.' ).
      ENDIF.
    ELSE.
      out->write( 'Validation errors found in transactional buffer.' ).
    ENDIF.

  ENDMETHOD.
ENDCLASS.
