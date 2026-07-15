@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Task'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_PPM_TASK as select from zppm_task_a
association to parent ZR_PPM_MILESTONE as _Milestone on $projection.MilestoneUuid = _Milestone.MilestoneUuid
{
    key task_uuid as TaskUuid,
    milestone_uuid as MilestoneUuid,
    task_id as TaskId,
    task_name as TaskName,
    description as Description,
    assigned_to as AssignedTo,
    priority as Priority,
    status as Status,
    due_date as DueDate,
    created_by as CreatedBy,
    created_at as CreatedAt,
    local_last_changed_by as LocalLastChangedBy,
    local_last_changed_at as LocalLastChangedAt,
    last_changed_at as LastChangedAt,
    
    _Milestone
}
