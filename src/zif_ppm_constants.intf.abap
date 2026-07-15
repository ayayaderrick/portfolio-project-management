INTERFACE zif_ppm_constants
  PUBLIC .

  "==========================
  " Project Status
  "==========================
  CONSTANTS:
    BEGIN OF project_status,
      new         TYPE zppm_project_status VALUE 'NEW',
      in_progress TYPE zppm_project_status VALUE 'INP',
      on_hold     TYPE zppm_project_status VALUE 'HLD',
      completed   TYPE zppm_project_status VALUE 'CMP',
      cancelled   TYPE zppm_project_status VALUE 'CAN',
    END OF project_status.

  "==========================
  " Milestone Status
  "==========================
  CONSTANTS:
    BEGIN OF milestone_status,
      new         TYPE zppm_milestone_status VALUE 'NEW',
      in_progress TYPE zppm_milestone_status VALUE 'INP',
      completed   TYPE zppm_milestone_status VALUE 'CMP',
    END OF milestone_status.

  "==========================
  " Task Status
  "==========================
  CONSTANTS:
    BEGIN OF task_status,
      open        TYPE zppm_task_status VALUE 'OPN',
      in_progress TYPE zppm_task_status VALUE 'INP',
      blocked     TYPE zppm_task_status VALUE 'BLK',
      done        TYPE zppm_task_status VALUE 'DON',
    END OF task_status.

  "==========================
  " Priority
  "==========================
  CONSTANTS:
      BEGIN OF priority,
        low type zppm_priority value 'LOW',
        medium type zppm_priority value 'MED',
        high type zppm_priority value 'HIG',
        critical type zppm_priority value 'CRT',
      END OF priority.

ENDINTERFACE.
