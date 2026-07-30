INTERFACE zif_ppm_state_area
  PUBLIC .

  CONSTANTS:
    BEGIN OF state_area,
      project_dates      TYPE string VALUE 'VALIDATE_PROJECT_DATES',
      milestone_due_date TYPE string VALUE 'VALIDATE_MILESTONE_DUE_DATE',
      task_due_date      TYPE string VALUE 'VALIDATE_TASK_DUE_DATE',
      sequence_no        TYPE string VALUE 'VALIDATE_SEQUENCE_NO',
      completed_task     TYPE string VALUE 'VALIDATE_COMPLETED_TASK',
    END OF state_area.

ENDINTERFACE.
