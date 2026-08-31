CLASS lhc_task DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    METHODS setTaskId FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Task~setTaskId.
    METHODS validateTaskDueDate FOR VALIDATE ON SAVE
      IMPORTING keys FOR Task~validateTaskDueDate.
    METHODS validateCompletedTask FOR VALIDATE ON SAVE
      IMPORTING keys FOR Task~validateCompletedTask.
    METHODS calculateProjectCompletion FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Task~calculateProjectCompletion.
    METHODS synchronizeMilestoneStatus FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Task~synchronizeMilestoneStatus.
    METHODS startTask FOR MODIFY
      IMPORTING keys FOR ACTION Task~startTask RESULT result.
    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR Task RESULT result.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR task RESULT result.
    METHODS blocktask FOR MODIFY
      IMPORTING keys FOR ACTION task~blocktask RESULT result.
    METHODS unblocktask FOR MODIFY
      IMPORTING keys FOR ACTION task~unblocktask RESULT result.
    METHODS completetask FOR MODIFY
      IMPORTING keys FOR ACTION task~completetask RESULT result.
    METHODS reopentask FOR MODIFY
      IMPORTING keys FOR ACTION task~reopentask RESULT result.


ENDCLASS.

CLASS lhc_task IMPLEMENTATION.

  METHOD setTaskId.

    TYPES: BEGIN OF ty_max_task_id,
             MilestoneUuid TYPE sysuuid_x16,
             max_task_id   TYPE zppm_task_id,
           END OF ty_max_task_id.
    DATA lv_max_id TYPE zppm_task_id.
    DATA lt_task_update TYPE TABLE FOR UPDATE zr_ppm_project\\Task.
    DATA lt_max_task_id TYPE SORTED TABLE OF ty_max_task_id WITH UNIQUE KEY milestoneuuid.

    READ ENTITIES OF zr_ppm_project IN LOCAL MODE
    ENTITY Task
    FIELDS ( MilestoneUuid TaskId )
    WITH CORRESPONDING #( keys )
    RESULT DATA(lt_tasks).

    " Ensure the method is strictly idempotent (ignore records already numbered)
    DELETE lt_tasks WHERE TaskId IS NOT INITIAL.
    IF lt_tasks IS INITIAL. RETURN. ENDIF.

    DATA(lt_milestone_parents) = lt_tasks.
    SORT lt_milestone_parents BY MilestoneUuid.
    DELETE ADJACENT DUPLICATES FROM lt_milestone_parents COMPARING MilestoneUuid.

    "--------------------------------------------------------------------------------------
    " Read the existing Tasks of every affected Milestone in a SINGLE batch call.
    " ABAP Cloud / RAP best practice: an EML statement must never sit inside a loop
    " So all parent Milestones' Tasks are read once here,
    " and the highest existing TaskId per Milestone is then determined purely in ABAP below.
    "--------------------------------------------------------------------------------------
    READ ENTITIES OF zr_ppm_project IN LOCAL MODE
    ENTITY Milestone BY \_Task
    FIELDS ( MilestoneUuid TaskId )
    WITH VALUE #( FOR parent IN lt_milestone_parents ( %tky = VALUE #( MilestoneUuid = parent-MilestoneUuid ) ) )
    RESULT DATA(lt_existing_tasks).

    LOOP AT lt_existing_tasks ASSIGNING FIELD-SYMBOL(<fs_existing_task>).
      ASSIGN lt_max_task_id[ milestoneuuid = <fs_existing_task>-MilestoneUuid ] TO FIELD-SYMBOL(<fs_max>).
      IF sy-subrc = 0.
        IF <fs_existing_task>-TaskId > <fs_max>-max_task_id.
          <fs_max>-max_task_id = <fs_existing_task>-TaskId.
        ENDIF.
      ELSE.
        INSERT VALUE #(
            milestoneuuid = <fs_existing_task>-MilestoneUuid
            max_task_id = <fs_existing_task>-TaskId
         ) INTO TABLE lt_max_task_id.
      ENDIF.
    ENDLOOP.

    "-----------------------------------------------------------------------
    " Assign sequential numbers per Milestone. This loop is pure ABAP
    " (table reads/appends only) - the single EML UPDATE call happens
    " once, after the loop, not inside it.
    "-----------------------------------------------------------------------
    LOOP AT lt_milestone_parents ASSIGNING FIELD-SYMBOL(<fs_milestone_parent>).
      READ TABLE lt_max_task_id ASSIGNING FIELD-SYMBOL(<fs_max_entry>)
          WITH TABLE KEY milestoneuuid = <fs_milestone_parent>-MilestoneUuid.
      IF sy-subrc = 0.
        lv_max_id = <fs_max_entry>-max_task_id.
      ELSE.
        lv_max_id = '0000000000'.
      ENDIF.

      " Assign numbers sequentially for bulk creation batches
      LOOP AT lt_tasks ASSIGNING FIELD-SYMBOL(<fs_task>) WHERE MilestoneUuid = <fs_milestone_parent>-MilestoneUuid
      AND TaskId IS INITIAL.
        lv_max_id += 1.

        APPEND VALUE #(
            %tky = <fs_task>-%tky
            TaskId = lv_max_id
         ) TO lt_task_update.

      ENDLOOP.

    ENDLOOP.

    IF lt_task_update IS NOT INITIAL.
      MODIFY ENTITIES OF zr_ppm_project IN LOCAL MODE
      ENTITY Task
      UPDATE FIELDS ( TaskId )
      WITH lt_task_update.
    ENDIF.

  ENDMETHOD.


  METHOD validateTaskDueDate.

    READ ENTITIES OF zr_ppm_project IN LOCAL MODE
    ENTITY Task
    FIELDS ( MilestoneUuid DueDate )
    WITH CORRESPONDING #( keys )
    RESULT DATA(lt_tasks).

    IF lt_tasks IS INITIAL. RETURN. ENDIF.

    DATA lt_milestone_keys TYPE TABLE FOR READ IMPORT zr_ppm_project\\Milestone.

    lt_milestone_keys = VALUE #( FOR task IN lt_tasks ( %key-MilestoneUuid = task-MilestoneUuid
                                                        %is_draft = task-%is_draft ) ).

    READ ENTITIES OF zr_ppm_project IN LOCAL MODE
    ENTITY Milestone
    FIELDS ( ProjectUuid DueDate )
    WITH lt_milestone_keys
    RESULT DATA(lt_milestones).

    LOOP AT lt_tasks ASSIGNING FIELD-SYMBOL(<fs_task>).
      " Clear existing state messages for this instance
      APPEND VALUE #(
          %tky = <fs_task>-%tky
          %state_area = zif_ppm_state_area=>state_area-task_due_date
       ) TO reported-task.

      " Read corresponding milestone safely
      ASSIGN lt_milestones[ KEY id MilestoneUuid = <fs_task>-MilestoneUuid
                            %is_draft = <fs_task>-%is_draft ] TO FIELD-SYMBOL(<fs_milestone>).

      IF sy-subrc <> 0. CONTINUE. ENDIF.

      IF <fs_task>-DueDate > <fs_milestone>-DueDate.
        APPEND VALUE #( %tky = <fs_task>-%tky ) TO failed-task.
        APPEND VALUE #(
            %tky = <fs_task>-%tky
            %msg = new_message(
                    id = 'ZPPM_MESSAGES'
                    number = '003'
                    severity = if_abap_behv_message=>severity-error )
            %element-DueDate = if_abap_behv=>mk-on
            %state_area = zif_ppm_state_area=>state_area-task_due_date
            %path = VALUE #( Project-ProjectUuid = <fs_milestone>-ProjectUuid
                             Project-%is_draft = <fs_milestone>-%is_draft
                             Milestone-%is_draft = <fs_task>-%is_draft
                             Milestone-MilestoneUuid = <fs_task>-MilestoneUuid )
         ) TO reported-task.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD validateCompletedTask.

    READ ENTITIES OF zr_ppm_project IN LOCAL MODE
    ENTITY Task
    FIELDS ( MilestoneUuid AssignedTo Status )
    WITH CORRESPONDING #( keys )
    RESULT DATA(lt_tasks)
    FAILED DATA(lt_failed_read).

    " Get Root Project Uuids by reading the parent Milestone entities
    DATA lt_milestone_keys TYPE TABLE FOR READ IMPORT zr_ppm_project\\Milestone.

    lt_milestone_keys = VALUE #( FOR task IN lt_tasks ( %key-MilestoneUuid = task-MilestoneUuid
                                                        %is_draft = task-%is_draft ) ).

    SORT lt_milestone_keys BY MilestoneUuid %is_draft.
    DELETE ADJACENT DUPLICATES FROM lt_milestone_keys COMPARING MilestoneUuid %is_draft.

    READ ENTITIES OF zr_ppm_project IN LOCAL MODE
    ENTITY Milestone
    FIELDS ( ProjectUuid DueDate )
    WITH lt_milestone_keys
    RESULT DATA(lt_milestones).

    LOOP AT lt_tasks ASSIGNING FIELD-SYMBOL(<fs_task>).
      " Clear existing state messages for this instance
      APPEND VALUE #( %tky = <fs_task>-%tky
                      %state_area = zif_ppm_state_area=>state_area-completed_task ) TO reported-task.

      " Ignore incomplete records
      IF <fs_task>-Status IS INITIAL. CONTINUE. ENDIF.

      " Read corresponding milestone safely
      ASSIGN lt_milestones[ KEY id MilestoneUuid = <fs_task>-MilestoneUuid
                            %is_draft = <fs_task>-%is_draft ] TO FIELD-SYMBOL(<fs_milestone>).

      IF sy-subrc <> 0. CONTINUE. ENDIF.

      " Validate only completed tasks with assigned owner
      IF <fs_task>-Status = zif_ppm_constants=>task_status-done
      AND <fs_task>-AssignedTo IS INITIAL.
        APPEND VALUE #( %tky = <fs_task>-%tky ) TO failed-task.
        APPEND VALUE #(
                        %tky = <fs_task>-%tky
                        %msg = new_message(
                                id = 'ZPPM_MESSAGES'
                                number = '005'
                                severity = if_abap_behv_message=>severity-error )
                        %element-AssignedTo = if_abap_behv=>mk-on
                        %state_area = zif_ppm_state_area=>state_area-completed_task
                        %path = VALUE #( Project-ProjectUuid = <fs_milestone>-ProjectUuid
                                         Project-%is_draft = <fs_milestone>-%is_draft
                                         Milestone-%is_draft = <fs_task>-%is_draft
                                         Milestone-MilestoneUuid = <fs_task>-MilestoneUuid )
             ) TO reported-task.

      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD calculateProjectCompletion.

    TYPES: BEGIN OF ty_milestone_project,
             MilestoneUuid TYPE sysuuid_x16,
             is_draft      TYPE abp_behv_flag,
             ProjectUuid   TYPE sysuuid_x16,
           END OF ty_milestone_project.
    TYPES: BEGIN OF ty_project_stats,
             ProjectUUID TYPE sysuuid_x16,
             is_draft    TYPE abp_behv_flag,
             total_tasks TYPE i,
             done_tasks  TYPE i,
           END OF ty_project_stats.

    DATA: lt_project_update    TYPE TABLE FOR UPDATE zr_ppm_project,
          lt_milestone_project TYPE SORTED TABLE OF ty_milestone_project WITH UNIQUE KEY MilestoneUuid is_draft,
          lt_project_stats     TYPE SORTED TABLE OF ty_project_stats WITH UNIQUE KEY ProjectUUID is_draft,
          lv_percentage        TYPE zppm_percentage,
          lv_percentage_df     TYPE decfloat34.

    "-----------------------------------------------------------------------
    " Read modified tasks
    "-----------------------------------------------------------------------
    READ ENTITIES OF zr_ppm_project IN LOCAL MODE
    ENTITY Task
    FIELDS ( MilestoneUuid )
    WITH CORRESPONDING #( keys )
    RESULT DATA(lt_tasks).

    IF lt_tasks IS INITIAL. RETURN. ENDIF.

    "-----------------------------------------------------------------------
    " Read affected milestones
    "-----------------------------------------------------------------------
    DATA lt_milestone_keys TYPE TABLE FOR READ IMPORT zr_ppm_project\\Milestone.

    lt_milestone_keys = VALUE #( FOR task IN lt_tasks ( %key-MilestoneUuid = task-MilestoneUuid
                                                        %is_draft = task-%is_draft ) ).

    SORT lt_milestone_keys BY MilestoneUuid %is_draft.
    DELETE ADJACENT DUPLICATES FROM lt_milestone_keys COMPARING MilestoneUuid %is_draft.

    READ ENTITIES OF zr_ppm_project IN LOCAL MODE
    ENTITY Milestone
    FIELDS ( ProjectUuid )
    WITH lt_milestone_keys
    RESULT DATA(lt_milestones).

    IF lt_milestones IS INITIAL. RETURN. ENDIF.

    "-----------------------------------------------------------------------
    " Determine affected projects
    "-----------------------------------------------------------------------
    DATA lt_project_keys TYPE TABLE FOR READ IMPORT zr_ppm_project.

    lt_project_keys = VALUE #( FOR milestone IN lt_milestones ( %key-ProjectUUID = milestone-ProjectUuid
                                                                %is_draft = milestone-%is_draft ) ).

    SORT lt_project_keys BY ProjectUUID %is_draft.
    DELETE ADJACENT DUPLICATES FROM lt_project_keys COMPARING ProjectUUID %is_draft.

    "---------------------------------------------------------------
    " Bulk Read complete Project hierarchy
    "---------------------------------------------------------------
    READ ENTITIES OF zr_ppm_project IN LOCAL MODE
    ENTITY Project BY \_Milestone
    ALL FIELDS
    WITH CORRESPONDING #( lt_project_keys )
    LINK DATA(lt_project_milestone_links)
    RESULT DATA(lt_all_milestones).

    READ ENTITIES OF zr_ppm_project IN LOCAL MODE
    ENTITY Milestone BY \_Task
    FIELDS ( Status )
    WITH CORRESPONDING #( lt_all_milestones )
    LINK DATA(lt_milestone_task_links)
    RESULT DATA(lt_all_tasks).

    "-----------------------------------------------------------------------
    " Aggregate total/done Task counts per Project (pure ABAP, no EML)
    "-----------------------------------------------------------------------
    lt_milestone_project = VALUE #( FOR milestone IN lt_all_milestones
                                     ( MilestoneUuid = milestone-MilestoneUuid
                                       is_draft       = milestone-%is_draft
                                       ProjectUuid    = milestone-ProjectUuid ) ).

    lt_project_stats = VALUE #( FOR project_key IN lt_project_keys
                                 ( ProjectUUID = project_key-ProjectUUID
                                   is_draft    = project_key-%is_draft ) ).

    LOOP AT lt_all_tasks ASSIGNING FIELD-SYMBOL(<fs_task>).
      ASSIGN lt_milestone_project[ MilestoneUuid = <fs_task>-MilestoneUuid
                                    is_draft       = <fs_task>-%is_draft ] TO FIELD-SYMBOL(<fs_ms_proj>).
      IF sy-subrc <> 0. CONTINUE. ENDIF.

      ASSIGN lt_project_stats[ ProjectUUID = <fs_ms_proj>-ProjectUuid
                                is_draft    = <fs_ms_proj>-is_draft ] TO FIELD-SYMBOL(<fs_stats>).
      IF sy-subrc <> 0. CONTINUE. ENDIF.

      <fs_stats>-total_tasks += 1.
      IF <fs_task>-Status = zif_ppm_constants=>task_status-done.
        <fs_stats>-done_tasks += 1.
      ENDIF.
    ENDLOOP.

    "-----------------------------------------------------------------------
    " Build the update table. This loop is pure ABAP (table reads/appends only)
    " the single EML UPDATE call happens once, after the loop, not inside it.
    "-----------------------------------------------------------------------
    LOOP AT lt_project_keys ASSIGNING FIELD-SYMBOL(<fs_proj_key>).
      CLEAR:  lv_percentage, lv_percentage_df.

      READ TABLE lt_project_stats ASSIGNING FIELD-SYMBOL(<fs_stats2>)
           WITH TABLE KEY ProjectUUID = <fs_proj_key>-ProjectUUID
                           is_draft    = <fs_proj_key>-%is_draft.

      IF sy-subrc = 0 AND <fs_stats2>-total_tasks > 0.
        lv_percentage_df = ( CONV decfloat34( <fs_stats2>-done_tasks ) * 100 )
                             / CONV decfloat34( <fs_stats2>-total_tasks ).
        lv_percentage = CONV zppm_percentage( lv_percentage_df ).
      ELSE.
        lv_percentage = 0.
      ENDIF.

      " Prepare the update structure for the root entity
      APPEND VALUE #(
          %tky = <fs_proj_key>-%tky
          CompletionPercentage = lv_percentage
          %control-CompletionPercentage = if_abap_behv=>mk-on
       ) TO lt_project_update.
    ENDLOOP.

    " Update the Project root entity with the new percentage
    IF lt_project_update IS NOT INITIAL.
      MODIFY ENTITIES OF zr_ppm_project IN LOCAL MODE
      ENTITY Project
      UPDATE FIELDS ( CompletionPercentage )
      WITH lt_project_update
      REPORTED DATA(lt_reported_modify).

      reported = CORRESPONDING #( DEEP lt_reported_modify ).
    ENDIF.

  ENDMETHOD.

  METHOD synchronizeMilestoneStatus.

    TYPES: BEGIN OF ty_milestone_stats,
             MilestoneUuid    TYPE sysuuid_x16,
             is_draft         TYPE abp_behv_flag,
             total_tasks      TYPE i,
             open_tasks       TYPE i,
             inprogress_tasks TYPE i,
             done_tasks       TYPE i,
           END OF ty_milestone_stats.

    DATA: lt_milestone_update TYPE TABLE FOR UPDATE zr_ppm_project\\Milestone,
          lt_milestone_stats  TYPE SORTED TABLE OF ty_milestone_stats WITH UNIQUE KEY MilestoneUuid is_draft,
          lv_new_status       TYPE zppm_task_status.

    "--------------------------------------------------------------------
    "Read changed Tasks
    "--------------------------------------------------------------------
    READ ENTITIES OF zr_ppm_project IN LOCAL MODE
    ENTITY Task
    FIELDS ( MilestoneUuid )
    WITH CORRESPONDING #( keys )
    RESULT DATA(lt_tasks).

    IF lt_tasks IS INITIAL. RETURN. ENDIF.

    "--------------------------------------------------------------------
    "Build unique Milestone keys
    "--------------------------------------------------------------------
    DATA lt_milestone_keys TYPE TABLE FOR READ IMPORT zr_ppm_project\\Milestone.

    lt_milestone_keys = VALUE #( FOR task IN lt_tasks ( %key-MilestoneUuid = task-MilestoneUuid
                                                        %is_draft = task-%is_draft ) ).

    SORT lt_milestone_keys BY MilestoneUuid %is_draft.
    DELETE ADJACENT DUPLICATES FROM lt_milestone_keys COMPARING MilestoneUuid %is_draft.

    "-----------------------------------------------------------------------
    " Bulk Read Milestone and all child Tasks
    "-----------------------------------------------------------------------
    READ ENTITIES OF zr_ppm_project IN LOCAL MODE
    ENTITY Milestone BY \_Task
    FIELDS ( MilestoneUuid Status )
    WITH CORRESPONDING #( lt_milestone_keys )
    LINK DATA(lt_task_links)
    RESULT DATA(lt_all_tasks).

    "-----------------------------------------------------------------------
    " Aggregate counts per Milestone
    "-----------------------------------------------------------------------
    " Seed one stats row per Milestone, so Milestones with zero Tasks still get updated (to NEW).
    lt_milestone_stats = VALUE #( FOR milestone_key IN lt_milestone_keys
                                   ( MilestoneUuid = milestone_key-MilestoneUuid
                                     is_draft       = milestone_key-%is_draft ) ).

    LOOP AT lt_all_tasks ASSIGNING FIELD-SYMBOL(<fs_task>).
      ASSIGN lt_milestone_stats[ MilestoneUuid = <fs_task>-MilestoneUuid
                                  is_draft       = <fs_task>-%is_draft ] TO FIELD-SYMBOL(<fs_stats>).
      IF sy-subrc <> 0. CONTINUE. ENDIF.

      <fs_stats>-total_tasks += 1.
      CASE <fs_task>-Status.
        WHEN zif_ppm_constants=>task_status-open.
          <fs_stats>-open_tasks += 1.
        WHEN zif_ppm_constants=>task_status-done.
          <fs_stats>-done_tasks += 1.
        WHEN OTHERS.
          <fs_stats>-inprogress_tasks += 1.
      ENDCASE.
    ENDLOOP.

    "-----------------------------------------------------------------------
    " Determine each Milestone's Status and build the update table.
    "-----------------------------------------------------------------------
    LOOP AT lt_milestone_keys ASSIGNING FIELD-SYMBOL(<fs_milestone_key>).
      CLEAR: lv_new_status.

      READ TABLE lt_milestone_stats ASSIGNING FIELD-SYMBOL(<fs_ms_stats>)
           WITH TABLE KEY MilestoneUuid = <fs_milestone_key>-MilestoneUuid
                           is_draft       = <fs_milestone_key>-%is_draft.

      IF sy-subrc <> 0 OR <fs_ms_stats>-total_tasks = 0.
        lv_new_status = zif_ppm_constants=>milestone_status-new.
      ELSEIF <fs_ms_stats>-done_tasks = <fs_ms_stats>-total_tasks.
        lv_new_status = zif_ppm_constants=>milestone_status-completed.
      ELSEIF <fs_ms_stats>-open_tasks = <fs_ms_stats>-total_tasks.
        lv_new_status = zif_ppm_constants=>milestone_status-new.
      ELSE.
        " Any mixture (including BLOCKED or IN_PROGRESS)
        " means work has started but is not complete.
        lv_new_status = zif_ppm_constants=>milestone_status-in_progress.
      ENDIF.

      "Prepare the update structure
      APPEND VALUE #(
        %tky = <fs_milestone_key>-%tky
        Status = lv_new_status
        %control-Status = if_abap_behv=>mk-on
       ) TO lt_milestone_update.

    ENDLOOP.

    IF lt_milestone_update IS NOT INITIAL.
      MODIFY ENTITIES OF zr_ppm_project IN LOCAL MODE
      ENTITY Milestone
      UPDATE FIELDS ( Status )
      WITH lt_milestone_update
      REPORTED DATA(lt_reported_modify).

      reported = CORRESPONDING #( DEEP lt_reported_modify ).
    ENDIF.

  ENDMETHOD.



  METHOD startTask.

    "---------------------------------------------------------------------
    " Read affected Tasks
    "---------------------------------------------------------------------
    READ ENTITIES OF zr_ppm_project IN LOCAL MODE
    ENTITY Task
    FIELDS ( Status )
    WITH CORRESPONDING #( keys )
    RESULT DATA(lt_tasks)
    FAILED failed.

    IF lt_tasks IS INITIAL. RETURN. ENDIF.

    "---------------------------------------------------------------------
    " Validate status transition
    "
    " OPEN -> IN_PROGRESS is the only valid transition.
    "---------------------------------------------------------------------
    LOOP AT lt_tasks ASSIGNING FIELD-SYMBOL(<fs_task>).
      IF <fs_task>-Status <> zif_ppm_constants=>task_status-open.
        APPEND VALUE #( %tky = <fs_task>-%tky ) TO failed-task.
        APPEND VALUE #(
           %tky = <fs_task>-%tky
           %msg = new_message(
                    id = 'ZPPM_MESSAGES'
                    number = '010'
                    severity = if_abap_behv_message=>severity-error )
         ) TO reported-task.
      ENDIF.
    ENDLOOP.

    "---------------------------------------------------------------------
    " Remove tasks that failed validation
    "---------------------------------------------------------------------
    DELETE lt_tasks WHERE Status <> zif_ppm_constants=>task_status-open.
    IF lt_tasks IS INITIAL. RETURN. ENDIF.

    "---------------------------------------------------------------------
    " Change Task status
    "---------------------------------------------------------------------
    MODIFY ENTITIES OF zr_ppm_project IN LOCAL MODE
    ENTITY Task
    UPDATE FIELDS ( Status )
    WITH VALUE #( FOR task IN lt_tasks ( %tky = task-%tky
                                         Status = zif_ppm_constants=>task_status-in_progress ) )
    FAILED DATA(lt_failed_modify)
    REPORTED DATA(lt_reported_modify).

    "---------------------------------------------------------------------
    " Propagate MODIFY failures/messages
    "---------------------------------------------------------------------
    failed = CORRESPONDING #( DEEP lt_failed_modify  ).
    reported = CORRESPONDING #( DEEP lt_reported_modify ).

    "---------------------------------------------------------------------
    " Read changed Tasks for action result
    "---------------------------------------------------------------------
    READ ENTITIES OF zr_ppm_project IN LOCAL MODE
    ENTITY Task
    ALL FIELDS WITH CORRESPONDING #( lt_tasks )
    RESULT DATA(lt_updated_tasks).

    "---------------------------------------------------------------------
    " Return changed instances
    "---------------------------------------------------------------------
    result = VALUE #( FOR task IN lt_updated_tasks ( %tky = task-%tky
                                                     %param = CORRESPONDING #( task ) ) ).

  ENDMETHOD.

  METHOD blockTask.

    "---------------------------------------------------------------------
    " Read affected Tasks
    "---------------------------------------------------------------------
    READ ENTITIES OF zr_ppm_project IN LOCAL MODE
    ENTITY Task
    FIELDS ( Status )
    WITH CORRESPONDING #( keys )
    RESULT DATA(lt_tasks)
    FAILED failed.

    IF lt_tasks IS INITIAL. RETURN. ENDIF.

    "---------------------------------------------------------------------
    " Validate status transition
    "
    " OPEN        -> BLOCKED   allowed
    " IN_PROGRESS -> BLOCKED   allowed
    " BLOCKED     -> BLOCKED   not allowed
    " DONE        -> BLOCKED   not allowed
    "---------------------------------------------------------------------
    LOOP AT lt_tasks ASSIGNING FIELD-SYMBOL(<fs_task>).
      IF <fs_task>-Status <> zif_ppm_constants=>task_status-open
      AND <fs_task>-Status <> zif_ppm_constants=>task_status-in_progress.
        APPEND VALUE #( %tky = <fs_task>-%tky ) TO failed-task.
        APPEND VALUE #(
           %tky = <fs_task>-%tky
           %msg = new_message(
                    id = 'ZPPM_MESSAGES'
                    number = '011'
                    severity = if_abap_behv_message=>severity-error )
         ) TO reported-task.
      ENDIF.
    ENDLOOP.

    "---------------------------------------------------------------------
    " Remove tasks that failed validation
    "---------------------------------------------------------------------
    DELETE lt_tasks WHERE Status <> zif_ppm_constants=>task_status-open
    AND Status <> zif_ppm_constants=>task_status-in_progress.
    IF lt_tasks IS INITIAL. RETURN. ENDIF.

    "---------------------------------------------------------------------
    " Set Task status to blocked
    "---------------------------------------------------------------------
    MODIFY ENTITIES OF zr_ppm_project IN LOCAL MODE
    ENTITY Task
    UPDATE FIELDS ( Status )
    WITH VALUE #( FOR task IN lt_tasks ( %tky = task-%tky
                                         Status = zif_ppm_constants=>task_status-blocked ) )
    FAILED DATA(lt_failed_modify)
    REPORTED DATA(lt_reported_modify).

    "---------------------------------------------------------------------
    " Propagate MODIFY failures/messages
    "---------------------------------------------------------------------
    failed = CORRESPONDING #( DEEP lt_failed_modify  ).
    reported = CORRESPONDING #( DEEP lt_reported_modify ).

    "---------------------------------------------------------------------
    " Read changed Tasks for action result
    "---------------------------------------------------------------------
    READ ENTITIES OF zr_ppm_project IN LOCAL MODE
    ENTITY Task
    ALL FIELDS WITH CORRESPONDING #( lt_tasks )
    RESULT DATA(lt_updated_tasks).

    "---------------------------------------------------------------------
    " Return changed instances
    "---------------------------------------------------------------------
    result = VALUE #( FOR task IN lt_updated_tasks ( %tky = task-%tky
                                                     %param = CORRESPONDING #( task ) ) ).

  ENDMETHOD.

  METHOD unblockTask.

    "---------------------------------------------------------------------
    " Read affected Tasks
    "---------------------------------------------------------------------
    READ ENTITIES OF zr_ppm_project IN LOCAL MODE
    ENTITY Task
    FIELDS ( Status )
    WITH CORRESPONDING #( keys )
    RESULT DATA(lt_tasks)
    FAILED failed.

    IF lt_tasks IS INITIAL. RETURN. ENDIF.

    "---------------------------------------------------------------------
    " Validate status transition
    "
    " BLOCKED -> IN_PROGRESS is the only valid transition.
    "---------------------------------------------------------------------
    LOOP AT lt_tasks ASSIGNING FIELD-SYMBOL(<fs_task>).
      IF <fs_task>-Status <> zif_ppm_constants=>task_status-blocked.
        APPEND VALUE #( %tky = <fs_task>-%tky ) TO failed-task.
        APPEND VALUE #(
           %tky = <fs_task>-%tky
           %msg = new_message(
                    id = 'ZPPM_MESSAGES'
                    number = '012'
                    severity = if_abap_behv_message=>severity-error )
         ) TO reported-task.
      ENDIF.
    ENDLOOP.

    "---------------------------------------------------------------------
    " Remove tasks that failed validation
    "---------------------------------------------------------------------
    DELETE lt_tasks WHERE Status <> zif_ppm_constants=>task_status-blocked.
    IF lt_tasks IS INITIAL. RETURN. ENDIF.

    "---------------------------------------------------------------------
    " Set Task status to in_progress
    "---------------------------------------------------------------------
    MODIFY ENTITIES OF zr_ppm_project IN LOCAL MODE
    ENTITY Task
    UPDATE FIELDS ( Status )
    WITH VALUE #( FOR task IN lt_tasks ( %tky = task-%tky
                                         Status = zif_ppm_constants=>task_status-in_progress ) )
    FAILED DATA(lt_failed_modify)
    REPORTED DATA(lt_reported_modify).

    "---------------------------------------------------------------------
    " Propagate MODIFY failures/messages
    "---------------------------------------------------------------------
    failed = CORRESPONDING #( DEEP lt_failed_modify  ).
    reported = CORRESPONDING #( DEEP lt_reported_modify ).

    "---------------------------------------------------------------------
    " Read changed Tasks for action result
    "---------------------------------------------------------------------
    READ ENTITIES OF zr_ppm_project IN LOCAL MODE
    ENTITY Task
    ALL FIELDS WITH CORRESPONDING #( lt_tasks )
    RESULT DATA(lt_updated_tasks).

    "---------------------------------------------------------------------
    " Return changed instances
    "---------------------------------------------------------------------
    result = VALUE #( FOR task IN lt_updated_tasks ( %tky = task-%tky
                                                     %param = CORRESPONDING #( task ) ) ).

  ENDMETHOD.

  METHOD completeTask.

    "---------------------------------------------------------------------
    " Read affected Tasks
    "---------------------------------------------------------------------
    READ ENTITIES OF zr_ppm_project IN LOCAL MODE
    ENTITY Task
    FIELDS ( Status )
    WITH CORRESPONDING #( keys )
    RESULT DATA(lt_tasks)
    FAILED failed.

    IF lt_tasks IS INITIAL. RETURN. ENDIF.

    "---------------------------------------------------------------------
    " Validate status transition
    "
    " IN_PROGRESS -> DONE is the only valid transition.
    "---------------------------------------------------------------------
    LOOP AT lt_tasks ASSIGNING FIELD-SYMBOL(<fs_task>).
      IF <fs_task>-Status <> zif_ppm_constants=>task_status-in_progress.
        APPEND VALUE #( %tky = <fs_task>-%tky ) TO failed-task.
        APPEND VALUE #(
           %tky = <fs_task>-%tky
           %msg = new_message(
                    id = 'ZPPM_MESSAGES'
                    number = '013'
                    severity = if_abap_behv_message=>severity-error )
         ) TO reported-task.
      ENDIF.
    ENDLOOP.

    "---------------------------------------------------------------------
    " Remove tasks that failed validation
    "---------------------------------------------------------------------
    DELETE lt_tasks WHERE Status <> zif_ppm_constants=>task_status-in_progress.
    IF lt_tasks IS INITIAL. RETURN. ENDIF.

    "---------------------------------------------------------------------
    " Set Task status to done
    "---------------------------------------------------------------------
    MODIFY ENTITIES OF zr_ppm_project IN LOCAL MODE
    ENTITY Task
    UPDATE FIELDS ( Status )
    WITH VALUE #( FOR task IN lt_tasks ( %tky = task-%tky
                                         Status = zif_ppm_constants=>task_status-done ) )
    FAILED DATA(lt_failed_modify)
    REPORTED DATA(lt_reported_modify).

    "---------------------------------------------------------------------
    " Propagate MODIFY failures/messages
    "---------------------------------------------------------------------
    failed = CORRESPONDING #( DEEP lt_failed_modify  ).
    reported = CORRESPONDING #( DEEP lt_reported_modify ).

    "---------------------------------------------------------------------
    " Read changed Tasks for action result
    "---------------------------------------------------------------------
    READ ENTITIES OF zr_ppm_project IN LOCAL MODE
    ENTITY Task
    ALL FIELDS WITH CORRESPONDING #( lt_tasks )
    RESULT DATA(lt_updated_tasks).

    "---------------------------------------------------------------------
    " Return changed instances
    "---------------------------------------------------------------------
    result = VALUE #( FOR task IN lt_updated_tasks ( %tky = task-%tky
                                                     %param = CORRESPONDING #( task ) ) ).

  ENDMETHOD.

  METHOD reopenTask.

    "---------------------------------------------------------------------
    " Read affected Tasks
    "---------------------------------------------------------------------
    READ ENTITIES OF zr_ppm_project IN LOCAL MODE
    ENTITY Task
    FIELDS ( Status )
    WITH CORRESPONDING #( keys )
    RESULT DATA(lt_tasks)
    FAILED failed.

    IF lt_tasks IS INITIAL. RETURN. ENDIF.

    "---------------------------------------------------------------------
    " Validate status transition
    "
    " DONE -> IN_PROGRESS is the only valid transition.
    "---------------------------------------------------------------------
    LOOP AT lt_tasks ASSIGNING FIELD-SYMBOL(<fs_task>).
      IF <fs_task>-Status <> zif_ppm_constants=>task_status-done.
        APPEND VALUE #( %tky = <fs_task>-%tky ) TO failed-task.
        APPEND VALUE #(
           %tky = <fs_task>-%tky
           %msg = new_message(
                    id = 'ZPPM_MESSAGES'
                    number = '014'
                    severity = if_abap_behv_message=>severity-error )
         ) TO reported-task.
      ENDIF.
    ENDLOOP.

    "---------------------------------------------------------------------
    " Remove tasks that failed validation
    "---------------------------------------------------------------------
    DELETE lt_tasks WHERE Status <> zif_ppm_constants=>task_status-done.
    IF lt_tasks IS INITIAL. RETURN. ENDIF.

    "---------------------------------------------------------------------
    " Set Task status to in_progress
    "---------------------------------------------------------------------
    MODIFY ENTITIES OF zr_ppm_project IN LOCAL MODE
    ENTITY Task
    UPDATE FIELDS ( Status )
    WITH VALUE #( FOR task IN lt_tasks ( %tky = task-%tky
                                         Status = zif_ppm_constants=>task_status-in_progress ) )
    FAILED DATA(lt_failed_modify)
    REPORTED DATA(lt_reported_modify).

    "---------------------------------------------------------------------
    " Propagate MODIFY failures/messages
    "---------------------------------------------------------------------
    failed = CORRESPONDING #( DEEP lt_failed_modify  ).
    reported = CORRESPONDING #( DEEP lt_reported_modify ).

    "---------------------------------------------------------------------
    " Read changed Tasks for action result
    "---------------------------------------------------------------------
    READ ENTITIES OF zr_ppm_project IN LOCAL MODE
    ENTITY Task
    ALL FIELDS WITH CORRESPONDING #( lt_tasks )
    RESULT DATA(lt_updated_tasks).

    "---------------------------------------------------------------------
    " Return changed instances
    "---------------------------------------------------------------------
    result = VALUE #( FOR task IN lt_updated_tasks ( %tky = task-%tky
                                                     %param = CORRESPONDING #( task ) ) ).

  ENDMETHOD.

  METHOD get_instance_features.

    READ ENTITIES OF zr_ppm_project IN LOCAL MODE
    ENTITY Task
    FIELDS ( Status )
    WITH CORRESPONDING #( keys )
    RESULT DATA(lt_tasks)
    FAILED failed.

    result = VALUE #( FOR task IN lt_tasks (
        %tky = task-%tky
        %action-startTask = COND #( WHEN task-Status = zif_ppm_constants=>task_status-open
                                    THEN if_abap_behv=>fc-o-enabled
                                    ELSE if_abap_behv=>fc-o-disabled )
        %action-blockTask = COND #( WHEN task-Status = zif_ppm_constants=>task_status-open
                                      OR task-Status = zif_ppm_constants=>task_status-in_progress
                                    THEN if_abap_behv=>fc-o-enabled
                                    ELSE if_abap_behv=>fc-o-disabled )
        %action-unblockTask = COND #( WHEN task-Status = zif_ppm_constants=>task_status-blocked
                                      THEN if_abap_behv=>fc-o-enabled
                                      ELSE if_abap_behv=>fc-o-disabled )
        %action-completeTask = COND #( WHEN task-Status = zif_ppm_constants=>task_status-in_progress
                                       THEN if_abap_behv=>fc-o-enabled
                                       ELSE if_abap_behv=>fc-o-disabled )
        %action-reopenTask = COND #( WHEN task-Status = zif_ppm_constants=>task_status-done
                                     THEN if_abap_behv=>fc-o-enabled
                                     ELSE if_abap_behv=>fc-o-disabled )
     ) ).

  ENDMETHOD.

  METHOD get_global_authorizations.
  ENDMETHOD.

ENDCLASS.

CLASS lhc_milestone DEFINITION INHERITING FROM cl_abap_behavior_handler.

  PRIVATE SECTION.

    METHODS setMilestoneId FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Milestone~setMilestoneId.
    METHODS validateMilestoneDueDate FOR VALIDATE ON SAVE
      IMPORTING keys FOR Milestone~validateMilestoneDueDate.
    METHODS validateSequenceNumber FOR VALIDATE ON SAVE
      IMPORTING keys FOR Milestone~validateSequenceNumber.
    METHODS synchronizeProjectStatus FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Milestone~synchronizeProjectStatus.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Milestone RESULT result.


ENDCLASS.

CLASS lhc_milestone IMPLEMENTATION.

  METHOD setMilestoneId.

    TYPES: BEGIN OF ty_max_milestone_id,
             ProjectUuid      TYPE sysuuid_x16,
             max_milestone_id TYPE zppm_milestone_id,
           END OF ty_max_milestone_id.

    DATA lv_max_id TYPE zppm_milestone_id.
    DATA lt_milestone_update TYPE TABLE FOR UPDATE zr_ppm_project\\Milestone.
    DATA lt_max_milestone_id TYPE SORTED TABLE OF ty_max_milestone_id WITH UNIQUE KEY projectuuid.

    READ ENTITIES OF zr_ppm_project IN LOCAL MODE
    ENTITY Milestone
    FIELDS ( ProjectUuid MilestoneId )
    WITH CORRESPONDING #( keys )
    RESULT DATA(lt_milestones).

    " Ensure the method is strictly idempotent (ignore records already numbered)
    DELETE lt_milestones WHERE MilestoneId IS NOT INITIAL.
    IF lt_milestones IS INITIAL. RETURN. ENDIF.

    DATA(lt_parents) = lt_milestones.
    SORT lt_parents BY ProjectUuid.
    DELETE ADJACENT DUPLICATES FROM lt_parents COMPARING ProjectUuid.

    "------------------------------------------------------------------------------------------
    " Read the existing Milestones of every affected Project in a SINGLE batch call.
    " ABAP Cloud / RAP best practice: an EML statement must never sit inside a loop
    " so this reads all parent Projects' Milestones at once,
    " and the highest existing MilestoneId per Project is then determined purely in ABAP below.
    "------------------------------------------------------------------------------------------
    " Reads both existing saved milestones and un-saved draft rows for this project
    READ ENTITIES OF zr_ppm_project IN LOCAL MODE
    ENTITY Project BY \_Milestone
    FIELDS ( ProjectUuid MilestoneId )
    WITH VALUE #( FOR parent IN lt_parents ( %tky = VALUE #( ProjectUUID = parent-ProjectUuid ) ) )
    RESULT DATA(lt_existing_milestones).

    LOOP AT lt_existing_milestones ASSIGNING FIELD-SYMBOL(<fs_existing_milestone>).
      ASSIGN lt_max_milestone_id[ projectuuid = <fs_existing_milestone>-ProjectUuid ] TO FIELD-SYMBOL(<fs_max>).
      IF sy-subrc = 0.
        IF <fs_existing_milestone>-MilestoneId > <fs_max>-max_milestone_id.
          <fs_max>-max_milestone_id = <fs_existing_milestone>-MilestoneId.
        ENDIF.
      ELSE.
        INSERT VALUE #(
            ProjectUuid = <fs_existing_milestone>-ProjectUuid
            max_milestone_id = <fs_existing_milestone>-MilestoneId
         ) INTO TABLE lt_max_milestone_id.
      ENDIF.
    ENDLOOP.

    "-----------------------------------------------------------------------
    " Assign sequential numbers per Project. This loop is pure ABAP
    " (table reads/appends only) - the single EML UPDATE call happens
    " once, after the loop, not inside it.
    "-----------------------------------------------------------------------
    LOOP AT lt_parents ASSIGNING FIELD-SYMBOL(<fs_parent>).
      READ TABLE lt_max_milestone_id ASSIGNING FIELD-SYMBOL(<fs_max_entry>)
          WITH TABLE KEY projectuuid = <fs_parent>-ProjectUuid.
      IF sy-subrc = 0.
        lv_max_id = <fs_max_entry>-max_milestone_id.
      ELSE.
        lv_max_id = '0000000000'.
      ENDIF.

      " Assign numbers sequentially for bulk creation batches
      LOOP AT lt_milestones ASSIGNING FIELD-SYMBOL(<fs_milestone>) WHERE ProjectUuid = <fs_parent>-ProjectUuid
      AND MilestoneId IS INITIAL.
        lv_max_id += 1.

        APPEND VALUE #(
            %tky = <fs_milestone>-%tky
            MilestoneId = lv_max_id
         ) TO lt_milestone_update.

      ENDLOOP.

    ENDLOOP.

    IF lt_milestone_update IS NOT INITIAL.
      MODIFY ENTITIES OF zr_ppm_project IN LOCAL MODE
      ENTITY Milestone
      UPDATE FIELDS ( MilestoneId )
      WITH lt_milestone_update.
    ENDIF.

  ENDMETHOD.

  METHOD validateMilestoneDueDate.

    READ ENTITIES OF zr_ppm_project IN LOCAL MODE
    ENTITY Milestone
    FIELDS ( ProjectUuid DueDate )
    WITH CORRESPONDING #( keys )
    RESULT DATA(lt_milestones).

    DATA lt_project_keys TYPE TABLE FOR READ IMPORT zr_ppm_project.

    lt_project_keys = VALUE #( FOR milestone IN lt_milestones ( %key-ProjectUUID = milestone-ProjectUuid ) ).

    READ ENTITIES OF zr_ppm_project IN LOCAL MODE
    ENTITY Project
    FIELDS ( StartDate EndDate )
    WITH lt_project_keys
    RESULT DATA(lt_projects).

    LOOP AT lt_milestones ASSIGNING FIELD-SYMBOL(<fs_milestone>).
      " Invalidate state messages
      APPEND VALUE #(
          %tky = <fs_milestone>-%tky
          %state_area = zif_ppm_state_area=>state_area-milestone_due_date
       ) TO reported-milestone.

      ASSIGN lt_projects[ KEY id ProjectUuid = <fs_milestone>-ProjectUuid
                          %is_draft = <fs_milestone>-%is_draft ] TO FIELD-SYMBOL(<fs_project>).

      IF sy-subrc <> 0. RETURN. ENDIF.

      IF <fs_milestone>-DueDate < <fs_project>-StartDate
      OR <fs_milestone>-DueDate > <fs_project>-EndDate.
        APPEND VALUE #( %tky = <fs_milestone>-%tky ) TO failed-milestone.
        APPEND VALUE #(
            %tky = <fs_milestone>-%tky
            %msg = new_message(
                    id = 'ZPPM_MESSAGES'
                    number = '002'
                    severity = if_abap_behv_message=>severity-error )
            %element-DueDate = if_abap_behv=>mk-on
            %state_area = zif_ppm_state_area=>state_area-milestone_due_date
            %path = VALUE #(
                                Project-%is_draft = <fs_milestone>-%is_draft
                                Project-ProjectUuid = <fs_milestone>-ProjectUuid )
         ) TO reported-milestone.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD validateSequenceNumber.

    " Read SequenceNo and ProjectUuid for the milestones being saved
    READ ENTITIES OF zr_ppm_project IN LOCAL MODE
    ENTITY Milestone
    FIELDS ( ProjectUuid SequenceNo )
    WITH CORRESPONDING #( keys )
    RESULT DATA(lt_target_milestones).

    IF lt_target_milestones IS INITIAL. RETURN. ENDIF.

    " Collect unique Project IDs to read ALL milestones within those projects
    DATA lt_project_keys TYPE TABLE FOR READ IMPORT zr_ppm_project\_Milestone.

    lt_project_keys = VALUE #( FOR milestone IN lt_target_milestones (
        %key-ProjectUUID = milestone-ProjectUuid
        %is_draft = milestone-%is_draft
     ) ).

    SORT lt_project_keys BY %key-ProjectUUID %is_draft.
    DELETE ADJACENT DUPLICATES FROM lt_project_keys COMPARING %key-ProjectUUID %is_draft.

    " Read ALL sibling milestones (captures both Draft buffer and Active DB data)
    READ ENTITIES OF zr_ppm_project IN LOCAL MODE
    ENTITY Project BY \_Milestone
    FIELDS ( SequenceNo )
    WITH lt_project_keys
    RESULT DATA(lt_all_milestones).

    " Group and evaluate duplicates
    LOOP AT lt_target_milestones ASSIGNING FIELD-SYMBOL(<fs_milestone>).
      " Clear any previous state messages for SequenceNumber on this instance
      APPEND VALUE #(
          %tky = <fs_milestone>-%tky
          %state_area = zif_ppm_state_area=>state_area-sequence_no
       ) TO reported-milestone.

      " Skip validation if sequence number is not provided yet
      IF <fs_milestone>-SequenceNo IS INITIAL. RETURN. ENDIF.

      " Count how many milestones in the same project share this sequence number
      DATA(lv_match_count) = REDUCE i(
         INIT count = 0
         FOR m IN lt_all_milestones USING KEY id
         WHERE ( ProjectUuid = <fs_milestone>-ProjectUuid AND
                 SequenceNo = <fs_milestone>-SequenceNo AND
                 %is_draft = <fs_milestone>-%is_draft )
         NEXT count = count + 1
      ).

      " If count > 1, a duplicate exists within the project context
      IF lv_match_count > 1.
        " Mark instance as failed to block the save operation
        APPEND VALUE #( %tky = <fs_milestone>-%tky ) TO failed-milestone.
        " Report the state message targeted directly at the SequenceNumber field
        APPEND VALUE #(
            %tky = <fs_milestone>-%tky
            %msg = new_message(
                    id = 'ZPPM_MESSAGES'
                    number = '004'
                    v1 = <fs_milestone>-SequenceNo
                    severity = if_abap_behv_message=>severity-error
             )
            %element-SequenceNo = if_abap_behv=>mk-on
            %state_area = zif_ppm_state_area=>state_area-sequence_no
            %path = VALUE #( Project-ProjectUuid = <fs_milestone>-ProjectUuid
                             Project-%is_draft = <fs_milestone>-%is_draft )
         ) TO reported-milestone.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.



  METHOD synchronizeProjectStatus.

    TYPES: BEGIN OF ty_project_stats,
             ProjectUUID           TYPE sysuuid_x16,
             is_draft              TYPE abap_boolean,
             total_milestones      TYPE i,
             new_milestones        TYPE i,
             inprogress_milestones TYPE i,
             completed_milestones  TYPE i,
           END OF ty_project_stats.

    DATA: lt_project_update TYPE TABLE FOR UPDATE zr_ppm_project,
          lt_project_stats  TYPE SORTED TABLE OF ty_project_stats WITH UNIQUE KEY ProjectUUID is_draft,
          lv_new_status     TYPE zppm_project_status.

    "-----------------------------------------------------------------------
    " Read changed Milestones
    "-----------------------------------------------------------------------
    READ ENTITIES OF zr_ppm_project IN LOCAL MODE
    ENTITY Milestone
    FIELDS ( ProjectUuid )
    WITH CORRESPONDING #( keys )
    RESULT DATA(lt_milestones).

    IF lt_milestones IS INITIAL. RETURN. ENDIF.

    "-----------------------------------------------------------------------
    " Build unique Project keys
    "-----------------------------------------------------------------------
    DATA lt_project_keys TYPE TABLE FOR READ IMPORT zr_ppm_project.

    lt_project_keys = VALUE #( FOR milestone IN lt_milestones (
        %key-ProjectUUID = milestone-ProjectUuid
        %is_draft = milestone-%is_draft
     ) ).

    SORT lt_project_keys BY ProjectUUID %is_draft.
    DELETE ADJACENT DUPLICATES FROM lt_project_keys COMPARING ProjectUUID %is_draft.

    "-----------------------------------------------------------------------
    " Bulk Read Project and child Milestones
    " This reads the full hierarchy for ALL affected Projects at once
    " The counts are then aggregated per Project purely in ABAP below.
    "-----------------------------------------------------------------------
    READ ENTITIES OF zr_ppm_project IN LOCAL MODE
    ENTITY Project BY \_Milestone
    FIELDS ( ProjectUuid Status )
    WITH CORRESPONDING #( lt_project_keys )
    LINK DATA(lt_project_links)
    RESULT DATA(lt_all_milestones).

    " Seed one stats row per Project, so Projects with zero Milestones still get updated (to NEW).
    lt_project_stats = VALUE #( FOR project_key IN lt_project_keys ( ProjectUUID = project_key-ProjectUUID
                                                                     is_draft    = project_key-%is_draft ) ).

    LOOP AT lt_all_milestones ASSIGNING FIELD-SYMBOL(<fs_milestone>).
      ASSIGN lt_project_stats[ ProjectUUID = <fs_milestone>-ProjectUuid
                               is_draft    = <fs_milestone>-%is_draft ] TO FIELD-SYMBOL(<fs_stats>).
      IF sy-subrc <> 0. CONTINUE. ENDIF.

      <fs_stats>-total_milestones += 1.
      CASE <fs_milestone>-Status.
        WHEN zif_ppm_constants=>milestone_status-new.
          <fs_stats>-new_milestones += 1.
        WHEN zif_ppm_constants=>milestone_status-completed.
          <fs_stats>-completed_milestones += 1.
        WHEN OTHERS.
          <fs_stats>-inprogress_milestones += 1.
      ENDCASE.
    ENDLOOP.

    "-----------------------------------------------------------------------
    " Determine each Project's Status and build the update table.
    "-----------------------------------------------------------------------
    LOOP AT lt_project_keys ASSIGNING FIELD-SYMBOL(<fs_project_key>).
      CLEAR: lv_new_status.

      READ TABLE lt_project_stats ASSIGNING FIELD-SYMBOL(<fs_proj_stats>)
           WITH TABLE KEY ProjectUUID = <fs_project_key>-ProjectUUID
                          is_draft    = <fs_project_key>-%is_draft.

      IF sy-subrc <> 0 OR <fs_proj_stats>-total_milestones = 0.
        lv_new_status = zif_ppm_constants=>project_status-new.
      ELSEIF <fs_proj_stats>-completed_milestones = <fs_proj_stats>-total_milestones.
        lv_new_status = zif_ppm_constants=>project_status-completed.
      ELSEIF <fs_proj_stats>-new_milestones = <fs_proj_stats>-total_milestones.
        lv_new_status = zif_ppm_constants=>project_status-new.
      ELSE.
        lv_new_status = zif_ppm_constants=>project_status-in_progress.
      ENDIF.

      APPEND VALUE #(
        %tky = <fs_project_key>-%tky
        Status = lv_new_status
        %control-Status = if_abap_behv=>mk-on
       ) TO lt_project_update.

    ENDLOOP.

    "-----------------------------------------------------------------------
    " Perfoem the update
    "-----------------------------------------------------------------------
    IF lt_project_update IS NOT INITIAL.
      MODIFY ENTITIES OF zr_ppm_project IN LOCAL MODE
      ENTITY Project
      UPDATE FIELDS ( Status )
      WITH lt_project_update
      REPORTED DATA(lt_reported_modify).

      reported = CORRESPONDING #( DEEP lt_reported_modify ).

    ENDIF.

  ENDMETHOD.

  METHOD get_global_authorizations.
  ENDMETHOD.

ENDCLASS.

CLASS lhc_zr_ppm_project DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS:
      get_global_authorizations FOR GLOBAL AUTHORIZATION
        IMPORTING
        REQUEST requested_authorizations FOR Project
        RESULT result,
      setProjectId FOR DETERMINE ON MODIFY
        IMPORTING keys FOR Project~setProjectId,
      validateProjectDates FOR VALIDATE ON SAVE
        IMPORTING keys FOR Project~validateProjectDates,
      startProject FOR MODIFY
        IMPORTING keys FOR ACTION Project~startProject RESULT result,
      get_instance_features FOR INSTANCE FEATURES
        IMPORTING keys REQUEST requested_features FOR Project RESULT result,
      putOnHold FOR MODIFY
        IMPORTING keys FOR ACTION Project~putOnHold RESULT result,
      resumeProject FOR MODIFY
        IMPORTING keys FOR ACTION Project~resumeProject RESULT result,
      cancelProject FOR MODIFY
        IMPORTING keys FOR ACTION Project~cancelProject RESULT result,
      setInitialProjectStatus FOR DETERMINE ON MODIFY
       keys FOR Project~setInitialProjectStatus.
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

    " Ensure Project ID is not set yet (idempotent)- must be checked when BO is draft-enabled
    DELETE lt_projects WHERE ProjectID IS NOT INITIAL AND ProjectID <> '0000000000'.
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
        RETURN.
    ENDTRY.

    project_id_max = number_range_key - number_range_returned_quantity.

    lt_update = VALUE #( FOR project IN lt_projects INDEX INTO lv_index (
        %tky = project-%tky
        ProjectID = project_id_max + lv_index
        %control-ProjectID = if_abap_behv=>mk-on
     ) ).

    MODIFY ENTITIES OF zr_ppm_project IN LOCAL MODE
    ENTITY Project
    UPDATE
    FIELDS ( ProjectID )
    WITH lt_update.


  ENDMETHOD.

  METHOD setInitialProjectStatus.

    DATA lt_update TYPE TABLE FOR UPDATE zr_ppm_project.

    READ ENTITIES OF zr_ppm_project IN LOCAL MODE
    ENTITY Project
    FIELDS ( Status )
    WITH CORRESPONDING #( keys )
    RESULT DATA(lt_projects).

    " Ensure Status is not set yet (idempotent) - must be checked when BO is draft-enabled
    DELETE lt_projects WHERE Status IS NOT INITIAL.
    IF lt_projects IS INITIAL. RETURN. ENDIF.

    lt_update = VALUE #( FOR project IN lt_projects (
        %tky = project-%tky
        Status = zif_ppm_constants=>project_status-new
        %control-Status = if_abap_behv=>mk-on
     ) ).

    MODIFY ENTITIES OF zr_ppm_project IN LOCAL MODE
    ENTITY Project
    UPDATE
    FIELDS ( Status )
    WITH lt_update.

  ENDMETHOD.

  METHOD validateProjectDates.

    READ ENTITIES OF zr_ppm_project IN LOCAL MODE
    ENTITY Project
    FIELDS ( StartDate EndDate )
    WITH CORRESPONDING #( keys )
    RESULT DATA(lt_projects).

    LOOP AT lt_projects INTO DATA(ls_project).
      " Invalidate state messages
      APPEND VALUE #(
          %tky = ls_project-%tky
          %state_area = zif_ppm_state_area=>state_area-project_dates
       ) TO reported-project.

      IF ls_project-StartDate IS INITIAL OR ls_project-EndDate IS INITIAL.
        CONTINUE.
      ENDIF.

      IF ls_project-StartDate > ls_project-EndDate.
        APPEND VALUE #( %tky = ls_project-%tky ) TO failed-project.
        APPEND VALUE #(
            %tky = ls_project-%tky
            %msg = new_message(
                    id = 'ZPPM_MESSAGES'
                    number = '001'
                    severity = if_abap_behv_message=>severity-error )
            %element-EndDate = if_abap_behv=>mk-on
            %state_area = zif_ppm_state_area=>state_area-project_dates
         ) TO reported-project.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.

  METHOD startProject.

    "---------------------------------------------------------------------
    " Read the affected Project instances
    "---------------------------------------------------------------------
    READ ENTITIES OF zr_ppm_project IN LOCAL MODE
    ENTITY Project
    FIELDS ( Status )
    WITH CORRESPONDING #( keys )
    RESULT DATA(lt_projects)
    FAILED failed.

    IF lt_projects IS INITIAL. RETURN. ENDIF.

    "---------------------------------------------------------------------
    " Validate the requested status transition
    " NEW -> IN_PROGRESS is the only valid transition for this action.
    " ON_HOLD and CANCELLED are deliberately handled by their own
    " actions later.
    "---------------------------------------------------------------------
    LOOP AT lt_projects ASSIGNING FIELD-SYMBOL(<fs_project>).
      IF <fs_project>-Status <> zif_ppm_constants=>project_status-new.
        APPEND VALUE #( %tky = <fs_project>-%tky ) TO failed-project.
        APPEND VALUE #(
            %tky = <fs_project>-%tky
            %msg = new_message(
                        id = 'ZPPM_MESSAGES'
                        number = '006'
                        severity = if_abap_behv_message=>severity-error )
         ) TO reported-project.
      ENDIF.
    ENDLOOP.

    "---------------------------------------------------------------------
    " Remove projects that failed validation
    "---------------------------------------------------------------------
    DELETE lt_projects WHERE Status <> zif_ppm_constants=>project_status-new.

    IF lt_projects IS INITIAL. RETURN. ENDIF.

    "---------------------------------------------------------------------
    " Change Project status
    "---------------------------------------------------------------------
    MODIFY ENTITIES OF zr_ppm_project IN LOCAL MODE
    ENTITY Project
    UPDATE FIELDS ( Status )
    WITH VALUE #( FOR project IN lt_projects (
                        %tky = project-%tky
                        Status = zif_ppm_constants=>project_status-in_progress ) )
    REPORTED DATA(lt_reported_modify)
    FAILED DATA(lt_failed_modify).

    "---------------------------------------------------------------------
    " Propagate errors/messages from the MODIFY request
    "---------------------------------------------------------------------
    reported = CORRESPONDING #( lt_reported_modify ).
    failed = CORRESPONDING #( lt_failed_modify ).

    "---------------------------------------------------------------------
    " Read changed Projects for the action result
    "---------------------------------------------------------------------
    READ ENTITIES OF zr_ppm_project IN LOCAL MODE
    ENTITY Project
    ALL FIELDS
    WITH CORRESPONDING #( lt_projects )
    RESULT DATA(lt_updated_projects).

    "---------------------------------------------------------------------
    " Return the modified Project instances
    "---------------------------------------------------------------------
    result = VALUE #( FOR project IN lt_updated_projects (
                            %tky = project-%tky
                            %param = CORRESPONDING #( project ) ) ).


  ENDMETHOD.

  METHOD putOnHold.

    "---------------------------------------------------------------------
    " Read the affected Project instances
    "---------------------------------------------------------------------
    READ ENTITIES OF zr_ppm_project IN LOCAL MODE
    ENTITY Project
    FIELDS ( Status )
    WITH CORRESPONDING #( keys )
    RESULT DATA(lt_projects)
    FAILED failed.

    IF lt_projects IS INITIAL. RETURN. ENDIF.

    "---------------------------------------------------------------------
    " Validate status transition
    "
    " NEW        -> ON_HOLD   allowed
    " IN_PROGRESS -> ON_HOLD  allowed
    " Everything else          rejected
    "---------------------------------------------------------------------
    LOOP AT lt_projects ASSIGNING FIELD-SYMBOL(<fs_project>).
      IF <fs_project>-Status <> zif_ppm_constants=>project_status-new
      AND <fs_project>-Status <> zif_ppm_constants=>project_status-in_progress.
        APPEND VALUE #( %tky = <fs_project>-%tky ) TO failed-project.
        APPEND VALUE #(
            %tky = <fs_project>-%tky
            %msg = new_message(
                        id = 'ZPPM_MESSAGES'
                        number = '007'
                        severity = if_abap_behv_message=>severity-error )
         ) TO reported-project.
      ENDIF.
    ENDLOOP.

    "---------------------------------------------------------------------
    " Remove projects that failed validation
    "---------------------------------------------------------------------
    DELETE lt_projects WHERE Status <> zif_ppm_constants=>project_status-new
    AND Status <> zif_ppm_constants=>project_status-in_progress.

    IF lt_projects IS INITIAL. RETURN. ENDIF.

    "---------------------------------------------------------------------
    " Set Project status to ON_HOLD
    "---------------------------------------------------------------------
    MODIFY ENTITIES OF zr_ppm_project IN LOCAL MODE
    ENTITY Project
    UPDATE FIELDS ( Status )
    WITH VALUE #( FOR project IN lt_projects (
                        %tky = project-%tky
                        Status = zif_ppm_constants=>project_status-on_hold ) )
    REPORTED DATA(lt_reported_modify)
    FAILED DATA(lt_failed_modify).

    "---------------------------------------------------------------------
    " Propagate errors/messages from the MODIFY request
    "---------------------------------------------------------------------
    reported = CORRESPONDING #( lt_reported_modify ).
    failed = CORRESPONDING #( lt_failed_modify ).

    "---------------------------------------------------------------------
    " Read changed Projects for the action result
    "---------------------------------------------------------------------
    READ ENTITIES OF zr_ppm_project IN LOCAL MODE
    ENTITY Project
    ALL FIELDS
    WITH CORRESPONDING #( lt_projects )
    RESULT DATA(lt_updated_projects).

    "---------------------------------------------------------------------
    " Return the modified Project instances
    "---------------------------------------------------------------------
    result = VALUE #( FOR project IN lt_updated_projects (
                            %tky = project-%tky
                            %param = CORRESPONDING #( project ) ) ).

  ENDMETHOD.

  METHOD resumeProject.

    "---------------------------------------------------------------------
    " Read the affected Project instances
    "---------------------------------------------------------------------
    READ ENTITIES OF zr_ppm_project IN LOCAL MODE
    ENTITY Project
    FIELDS ( Status )
    WITH CORRESPONDING #( keys )
    RESULT DATA(lt_projects)
    FAILED failed.

    IF lt_projects IS INITIAL. RETURN. ENDIF.

    "---------------------------------------------------------------------
    " Validate status transition
    " ON_HOLD -> IN_PROGRESS is the only valid transition.
    "---------------------------------------------------------------------
    LOOP AT lt_projects ASSIGNING FIELD-SYMBOL(<fs_project>).
      IF <fs_project>-Status <> zif_ppm_constants=>project_status-on_hold.
        APPEND VALUE #( %tky = <fs_project>-%tky ) TO failed-project.
        APPEND VALUE #(
            %tky = <fs_project>-%tky
            %msg = new_message(
                        id = 'ZPPM_MESSAGES'
                        number = '008'
                        severity = if_abap_behv_message=>severity-error )
         ) TO reported-project.
      ENDIF.
    ENDLOOP.

    "---------------------------------------------------------------------
    " Remove projects that failed validation
    "---------------------------------------------------------------------
    DELETE lt_projects WHERE Status <> zif_ppm_constants=>project_status-on_hold.

    IF lt_projects IS INITIAL. RETURN. ENDIF.

    "---------------------------------------------------------------------
    " Set Project status to in_progress
    "---------------------------------------------------------------------
    MODIFY ENTITIES OF zr_ppm_project IN LOCAL MODE
    ENTITY Project
    UPDATE FIELDS ( Status )
    WITH VALUE #( FOR project IN lt_projects (
                        %tky = project-%tky
                        Status = zif_ppm_constants=>project_status-in_progress ) )
    REPORTED DATA(lt_reported_modify)
    FAILED DATA(lt_failed_modify).

    "---------------------------------------------------------------------
    " Propagate errors/messages from the MODIFY request
    "---------------------------------------------------------------------
    reported = CORRESPONDING #( lt_reported_modify ).
    failed = CORRESPONDING #( lt_failed_modify ).

    "---------------------------------------------------------------------
    " Read changed Projects for the action result
    "---------------------------------------------------------------------
    READ ENTITIES OF zr_ppm_project IN LOCAL MODE
    ENTITY Project
    ALL FIELDS
    WITH CORRESPONDING #( lt_projects )
    RESULT DATA(lt_updated_projects).

    "---------------------------------------------------------------------
    " Return the modified Project instances
    "---------------------------------------------------------------------
    result = VALUE #( FOR project IN lt_updated_projects (
                            %tky = project-%tky
                            %param = CORRESPONDING #( project ) ) ).


  ENDMETHOD.


  METHOD cancelProject.

    "---------------------------------------------------------------------
    " Read the affected Project instances
    "---------------------------------------------------------------------
    READ ENTITIES OF zr_ppm_project IN LOCAL MODE
    ENTITY Project
    FIELDS ( Status )
    WITH CORRESPONDING #( keys )
    RESULT DATA(lt_projects)
    FAILED failed.

    IF lt_projects IS INITIAL. RETURN. ENDIF.

    "---------------------------------------------------------------------
    " Validate status transition "
    " NEW         -> CANCELLED  allowed
    " IN_PROGRESS -> CANCELLED  allowed
    " ON_HOLD     -> CANCELLED  allowed
    " COMPLETED   -> CANCELLED  not allowed
    " CANCELLED   -> CANCELLED  not allowed
    "---------------------------------------------------------------------
    LOOP AT lt_projects ASSIGNING FIELD-SYMBOL(<fs_project>).
      IF <fs_project>-Status <> zif_ppm_constants=>project_status-new
      AND <fs_project>-Status <> zif_ppm_constants=>project_status-in_progress
      AND <fs_project>-Status <> zif_ppm_constants=>project_status-on_hold.
        APPEND VALUE #( %tky = <fs_project>-%tky ) TO failed-project.
        APPEND VALUE #(
            %tky = <fs_project>-%tky
            %msg = new_message(
                        id = 'ZPPM_MESSAGES'
                        number = '009'
                        severity = if_abap_behv_message=>severity-error )
         ) TO reported-project.
      ENDIF.
    ENDLOOP.

    "---------------------------------------------------------------------
    " Remove projects that failed validation
    "---------------------------------------------------------------------
    DELETE lt_projects WHERE Status <> zif_ppm_constants=>project_status-new
      AND Status <> zif_ppm_constants=>project_status-in_progress
      AND Status <> zif_ppm_constants=>project_status-on_hold.

    IF lt_projects IS INITIAL. RETURN. ENDIF.

    "---------------------------------------------------------------------
    " Set Project status to cancelled
    "---------------------------------------------------------------------
    MODIFY ENTITIES OF zr_ppm_project IN LOCAL MODE
    ENTITY Project
    UPDATE FIELDS ( Status )
    WITH VALUE #( FOR project IN lt_projects (
                        %tky = project-%tky
                        Status = zif_ppm_constants=>project_status-cancelled ) )
    REPORTED DATA(lt_reported_modify)
    FAILED DATA(lt_failed_modify).

    "---------------------------------------------------------------------
    " Propagate errors/messages from the MODIFY request
    "---------------------------------------------------------------------
    reported = CORRESPONDING #( lt_reported_modify ).
    failed = CORRESPONDING #( lt_failed_modify ).

    "---------------------------------------------------------------------
    " Read changed Projects for the action result
    "---------------------------------------------------------------------
    READ ENTITIES OF zr_ppm_project IN LOCAL MODE
    ENTITY Project
    ALL FIELDS
    WITH CORRESPONDING #( lt_projects )
    RESULT DATA(lt_updated_projects).

    "---------------------------------------------------------------------
    " Return the modified Project instances
    "---------------------------------------------------------------------
    result = VALUE #( FOR project IN lt_updated_projects (
                            %tky = project-%tky
                            %param = CORRESPONDING #( project ) ) ).

  ENDMETHOD.

  METHOD get_instance_features.

    READ ENTITIES OF zr_ppm_project IN LOCAL MODE
    ENTITY Project
    FIELDS ( Status )
    WITH CORRESPONDING #( keys )
    RESULT DATA(lt_projects)
    FAILED failed.

    result = VALUE #( FOR project IN lt_projects (
        %tky = project-%tky
        %action-startProject = COND #( WHEN project-Status = zif_ppm_constants=>project_status-new
                                       THEN if_abap_behv=>fc-o-enabled
                                       ELSE if_abap_behv=>fc-o-disabled )
        %action-putOnHold = COND #( WHEN project-Status = zif_ppm_constants=>project_status-new
                                      OR project-Status = zif_ppm_constants=>project_status-in_progress
                                    THEN if_abap_behv=>fc-o-enabled
                                    ELSE if_abap_behv=>fc-o-disabled )
        %action-resumeProject = COND #( WHEN project-Status = zif_ppm_constants=>project_status-on_hold
                                        THEN if_abap_behv=>fc-o-enabled
                                        ELSE if_abap_behv=>fc-o-disabled )
        %action-cancelProject = COND #( WHEN project-Status = zif_ppm_constants=>project_status-new
                                          OR project-Status = zif_ppm_constants=>project_status-in_progress
                                          OR project-Status = zif_ppm_constants=>project_status-on_hold
                                        THEN if_abap_behv=>fc-o-enabled
                                        ELSE if_abap_behv=>fc-o-disabled )
     ) ).

  ENDMETHOD.



ENDCLASS.
















