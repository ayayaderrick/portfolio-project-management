# Portfolio Project Management (PPM)

An SAP ABAP RESTful Application Programming Model (RAP) sample application for managing a portfolio of **Projects**, each broken down into **Milestones**, and each Milestone broken down into **Tasks** — with a Fiori Elements UI, draft handling, business actions, and status roll-up logic implemented as RAP determinations and validations.

## Overview

This repository implements a fully worked managed RAP business object with a three-level composition hierarchy:

```
Project (1) ──< Milestone (N) ──< Task (N)
```

- A **Project** has a name, description, start/end dates, an overall status, and a computed completion percentage.
- A **Milestone** belongs to a Project, has a sequence number and due date, and a status derived from its Tasks.
- A **Task** belongs to a Milestone, has a priority, due date, assignee, and status; task status drives both its parent Milestone's status and the Project's completion percentage.

The business object is draft-enabled, so users can create and edit Projects (and their Milestones/Tasks) as drafts before saving/activating them, matching standard Fiori Elements "create/edit" UX.

## Architecture

| Layer | Object | Purpose |
|---|---|---|
| Persistence | `ZPPM_PROJECT_A` / `ZPPM_PROJECT_D`, `ZPPM_MILESTONE_A` / `ZPPM_MILESTOME_D`, `ZPPM_TASK_A` / `ZPPM_TASK_D` | Active and draft database tables for each node |
| Interface (root) | `ZR_PPM_PROJECT` (CDS view + `ZR_PPM_PROJECT` behavior definition) | Root managed, draft-enabled RAP business object |
| Interface (children) | `ZR_PPM_MILESTONE`, `ZR_PPM_TASK` | CDS interface views for the Milestone and Task nodes |
| Behavior implementation | `ZBP_R_PPM_PROJECT` | Determinations, validations, and actions for all three nodes |
| Projection | `ZC_PPM_PROJECT`, `ZC_PPM_MILESTONE`, `ZC_PPM_TASK` (+ `ZBP_C_PPM_PROJECT`) | Consumption view exposed to OData/Fiori, with UI annotations (`.ddlx`) |
| Service | `ZUI_PPM_PROJECT_O4` (service definition + OData V4 UI service binding) | Exposes Project/Milestone/Task to a Fiori Elements app |
| Value helps | `ZI_PPM_PROJECTSTATUS_VH`, `ZI_PPM_MILESTONESTATUS_VH`, `ZI_PPM_TASKSTATUS_VH`, `ZI_PPM_PRIORITY_VH`, `ZI_PPM_CODELIST(TEXT)` | Drop-down value helps backed by a generic codelist table |
| Analytics | `ZI_PPM_TASKAGGREGATE` | Aggregates task counts/completed counts per Project |
| Utilities | `ZCL_PPM_DEMO_DATA`, `ZCL_SEED_CODELIST_DATA`, `ZCL_CREATE_NR_INTRVL` | One-off classes to seed demo data, seed codelist value-help entries, and create the number range interval |
| Shared logic | `ZIF_PPM_CONSTANTS`, `ZIF_PPM_STATE_AREA` | Status/priority constants and validation state-area identifiers used across the behavior pool |
| Messages | `ZPPM_MESSAGES` | Message class for validation and action-guard messages |
| Tests | `ZBP_R_PPM_PROJECT` (Test Classes include) | ABAP Unit tests for the behavior pool, using the CDS Test Double Framework |

## Data model

- **Project** — `ProjectUUID` (technical key), `ProjectID` (business ID, number-range assigned), `ProjectName`, `Description`, `StartDate`, `EndDate`, `Status`, `CompletionPercentage`.
- **Milestone** — `MilestoneUuid`, `MilestoneId` (sequential per Project), `ProjectUuid` (parent), `MilestoneName`, `Description`, `SequenceNo`, `DueDate`, `Status`.
- **Task** — `TaskUuid`, `TaskId` (sequential per Milestone), `MilestoneUuid` (parent), `TaskName`, `Description`, `Priority`, `DueDate`, `AssignedTo`, `Status`.

### Status values (`ZIF_PPM_CONSTANTS`)

| Project | Milestone | Task | Priority |
|---|---|---|---|
| `NEW` | `NEW` | `OPEN` | `LOW` |
| `IN_PROGRESS` | `IN_PROGRESS` | `IN_PROGRESS` | `MEDIUM` |
| `ON_HOLD` | `COMPLETED` | `BLOCKED` | `HIGH` |
| `COMPLETED` | | `DONE` | `CRITICAL` |
| `CANCELLED` | | | |

## Business logic

### Determinations (`ON MODIFY`)

- **`setInitialProjectStatus`** — initializes a new Project's `Status` to `NEW` on creation.
- **`setProjectId` / `setMilestoneId` / `setTaskId`** — assign business IDs: `ProjectID` via a number range object (`ZPPM_NR`), `MilestoneId`/`TaskId` sequentially per parent.
- **`synchronizeProjectStatus`** — rolls a Project's Milestones up into the Project's `Status` (all new → `NEW`, all completed → `COMPLETED`, otherwise → `IN_PROGRESS`).
- **`synchronizeMilestoneStatus`** — rolls a Milestone's Tasks up into the Milestone's `Status`, using the same all-new/all-done/mixed logic.
- **`calculateProjectCompletion`** — computes `CompletionPercentage` as `(done tasks / total tasks) × 100` across the whole Project's Milestone/Task subtree.

### Validations (`ON SAVE`)

- **`validateProjectDates`** — rejects a Project whose `EndDate` is before its `StartDate`.
- **`validateMilestoneDueDate`** — rejects a Milestone due date outside its Project's start/end range.
- **`validateSequenceNumber`** — rejects duplicate `SequenceNo` values among Milestones of the same Project.
- **`validateTaskDueDate`** — rejects a Task due date later than its Milestone's due date.
- **`validateCompletedTask`** — rejects a `DONE` Task that has no `AssignedTo`.

### Actions

| Entity | Actions | Allowed transitions |
|---|---|---|
| Project | `startProject`, `putOnHold`, `resumeProject`, `cancelProject` | `NEW → IN_PROGRESS`, `NEW/IN_PROGRESS → ON_HOLD`, `ON_HOLD → IN_PROGRESS`, `NEW/IN_PROGRESS/ON_HOLD → CANCELLED` |
| Task | `startTask`, `blockTask`, `unblockTask`, `completeTask`, `reopenTask` | `OPEN → IN_PROGRESS`, `OPEN/IN_PROGRESS → BLOCKED`, `BLOCKED → IN_PROGRESS`, `IN_PROGRESS → DONE`, `DONE → IN_PROGRESS` |

Draft handling also exposes the standard `Edit`, `Activate`, `Discard`, `Resume`, and `Prepare` draft actions on the Project root.

## Repository layout

```
src/
├── zr_ppm_project.*            Root interface CDS view + behavior definition (draft-enabled)
├── zr_ppm_milestone.*          Milestone interface CDS view
├── zr_ppm_task.*                Task interface CDS view
├── zc_ppm_project.*            Project consumption/projection view + behavior definition
├── zc_ppm_milestone.*          Milestone projection view + UI annotations (.ddlx)
├── zc_ppm_task.*                Task projection view + UI annotations (.ddlx)
├── zbp_r_ppm_project.clas.*     Behavior pool: determinations, validations, actions, and ABAP Unit tests
├── zbp_c_ppm_project.clas.*     Projection-level behavior implementation
├── zui_ppm_project_o4.*        OData V4 UI service definition + service binding
├── zi_ppm_taskaggregate.*      CDS analytical view: task/completed-task counts per Project
├── zi_ppm_*_vh.*                Value help views (status codes, priority)
├── zi_ppm_codelist*.*           Generic codelist + text views backing the value helps
├── zif_ppm_constants.intf.abap  Status/priority constants
├── zif_ppm_state_area.intf.abap Validation state-area identifiers
├── zppm_messages.msag.xml       Message class
├── zppm_*.doma.xml / *.dtel.xml Domains and data elements
├── zppm_*_a.tabl.xml / *_d.tabl.xml   Active/draft persistence tables
├── zppm_nr.nrob.xml             Number range object for Project IDs
├── zcl_ppm_demo_data.clas.abap  Seeds demo Projects/Milestones/Tasks
├── zcl_seed_codelist_data.clas.abap  Seeds value-help codelist entries
└── zcl_create_nr_intrvl.clas.abap    Creates the ZPPM_NR number range interval
```

## Getting started

1. **Import the repository** into your ABAP Cloud / BTP ABAP Environment (or an on-premise system with abapGit and RAP support) via [abapGit](https://abapgit.org/), or clone it as an ADT project.
2. **Create the number range interval.** Run `ZCL_CREATE_NR_INTRVL` as an ADT console application (`if_oo_adt_classrun`) once per system to create interval `01` for number range object `ZPPM_NR`, which `setProjectId` depends on.
3. **Seed value-help data (optional).** Run `ZCL_SEED_CODELIST_DATA` to populate the generic codelist tables backing the status/priority value helps.
4. **Seed demo data (optional).** Run `ZCL_PPM_DEMO_DATA` to create a set of sample Projects with Milestones and Tasks.
5. **Publish and run the UI.** Activate and publish the service binding `ZUI_PPM_PROJECT_O4` (OData V4, UI) in ADT, then preview it to get a generated Fiori Elements list report / object page for Projects, with Milestones and Tasks as sub-object pages.

## Running the tests

The behavior pool ships with an ABAP Unit test class (`ZBP_R_PPM_PROJECT`'s Test Classes include) that exercises the determinations, validations, and actions described above using the **CDS Test Double Framework**, so tests run in isolation against doubled tables rather than real data.

- Run via ADT: right-click `ZBP_R_PPM_PROJECT` → **Run As → ABAP Unit Test**.
- The tests assume the `ZPPM_NR` / interval `01` number range object already exists (see step 2 above), since `setProjectId` allocates a real number range for `ProjectID`.

## License

Released under the [MIT License](LICENSE).
