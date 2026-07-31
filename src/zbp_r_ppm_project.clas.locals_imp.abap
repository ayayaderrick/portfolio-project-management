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


ENDCLASS.

CLASS lhc_task IMPLEMENTATION.

  METHOD setTaskId.

    DATA lv_max_id TYPE zppm_task_id.
    DATA lt_task_update TYPE TABLE FOR UPDATE zr_ppm_project\\Task.

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

    LOOP AT lt_milestone_parents ASSIGNING FIELD-SYMBOL(<fs_milestone_parent>).
      " Read tasks associated with this specific parent milestone (active + draft)
      READ ENTITIES OF zr_ppm_project IN LOCAL MODE
      ENTITY Milestone BY \_Task
      FIELDS ( TaskId )
      WITH VALUE #( ( %tky = VALUE #( MilestoneUuid = <fs_milestone_parent>-MilestoneUuid ) ) )
      RESULT DATA(lt_existing_tasks).

      SORT lt_existing_tasks BY TaskId DESCENDING.
      lv_max_id = '0000000000'.
      IF lt_existing_tasks IS NOT INITIAL.
        lv_max_id = lt_existing_tasks[ 1 ]-TaskId.
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
      ASSIGN lt_milestones[ MilestoneUuid = <fs_task>-MilestoneUuid
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
    RESULT DATA(lt_tasks).

    IF keys IS INITIAL. RETURN. ENDIF.

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
      ASSIGN lt_milestones[ MilestoneUuid = <fs_task>-MilestoneUuid
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

    DATA: lt_project_update TYPE TABLE FOR UPDATE zr_ppm_project,
          lv_total_tasks    TYPE i,
          lv_done_tasks     TYPE i,
          lv_pecentage      TYPE p LENGTH 3 DECIMALS 2.

    " Get the Root Project UUIDs for all modified Tasks to handle mass processing
    READ ENTITIES OF zr_ppm_project IN LOCAL MODE
    ENTITY Task
    FIELDS ( MilestoneUuid )
    WITH CORRESPONDING #( keys )
    RESULT DATA(lt_tasks).

    IF keys IS INITIAL. RETURN. ENDIF.

    " Get Root Project Uuids by reading the parent Milestone entities
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

    DATA lt_project_keys TYPE TABLE FOR READ IMPORT zr_ppm_project.

    lt_project_keys = VALUE #( FOR milestone IN lt_milestones ( %key-ProjectUUID = milestone-ProjectUuid
                                                                %is_draft = milestone-%is_draft ) ).

    SORT lt_project_keys BY ProjectUUID %is_draft.
    DELETE ADJACENT DUPLICATES FROM lt_project_keys COMPARING ProjectUUID %is_draft.

    LOOP AT lt_project_keys ASSIGNING FIELD-SYMBOL(<fs_proj_key>).
      CLEAR: lv_total_tasks, lv_done_tasks, lv_pecentage.

      READ ENTITIES OF zr_ppm_project IN LOCAL MODE
      ENTITY Project BY \_Milestone
      FROM VALUE #( ( %tky = <fs_proj_key>-%tky ) )
      RESULT DATA(lt_all_milestones)
      ENTITY Milestone BY \_Task
      FIELDS ( Status )
      WITH VALUE #( FOR mstn IN lt_all_milestones ( %tky = mstn-%tky ) )
      RESULT DATA(lt_all_project_tasks).

      lv_total_tasks = lines( lt_all_project_tasks ).

      IF lv_total_tasks > 0.
        lv_done_tasks = REDUCE i( INIT count = 0
                            FOR task IN lt_all_project_tasks
                            WHERE ( Status = zif_ppm_constants=>task_status-done )
                            NEXT count += 1 ).
        lv_pecentage = ( lv_done_tasks / lv_total_tasks ) * 100.
      ELSE.
        lv_pecentage = 0.
      ENDIF.

      " Prepare the update structure for the root entity
      APPEND VALUE #(
          %tky = <fs_proj_key>-%tky
          CompletionPercentage = lv_pecentage
          %control-CompletionPercentage = if_abap_behv=>mk-on
       ) TO lt_project_update.
    ENDLOOP.

    " Update the Project root entity with the new percentage
    MODIFY ENTITIES OF zr_ppm_project IN LOCAL MODE
    ENTITY Project
    UPDATE FIELDS ( CompletionPercentage )
    WITH lt_project_update
    REPORTED DATA(lt_reported_modify).

    reported = CORRESPONDING #( DEEP lt_reported_modify ).

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

ENDCLASS.

CLASS lhc_milestone IMPLEMENTATION.

  METHOD setMilestoneId.

    DATA lv_max_id TYPE zppm_milestone_id.
    DATA lt_milestone_update TYPE TABLE FOR UPDATE zr_ppm_project\\Milestone.

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

    LOOP AT lt_parents ASSIGNING FIELD-SYMBOL(<fs_parent>).
      " Reads both existing saved milestones and un-saved draft rows for this project
      READ ENTITIES OF zr_ppm_project IN LOCAL MODE
      ENTITY Project BY \_Milestone
      FIELDS ( MilestoneId )
      WITH VALUE #( ( %tky = VALUE #( ProjectUUID = <fs_parent>-ProjectUuid ) ) )
      RESULT DATA(lt_existing_milestones).

      SORT lt_existing_milestones BY MilestoneId DESCENDING.
      lv_max_id = '0000000000'.
      IF lt_existing_milestones IS NOT INITIAL.
        lv_max_id = lt_existing_milestones[ 1 ]-MilestoneId.
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

      ASSIGN lt_projects[ ProjectUuid = <fs_milestone>-ProjectUuid
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
         FOR m IN lt_all_milestones
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
        IMPORTING keys FOR Project~validateProjectDates.
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

ENDCLASS.
