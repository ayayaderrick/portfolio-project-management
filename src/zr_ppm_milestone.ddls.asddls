@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Milestone'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_PPM_MILESTONE as select from zppm_milestone_a
association to parent ZR_PPM_PROJECT as _Project on $projection.ProjectUuid = _Project.ProjectUUID
composition [0..*] of ZR_PPM_TASK as _Task
{
    key milestone_uuid as MilestoneUuid,
    project_uuid as ProjectUuid,
    milestone_id as MilestoneId,
    milestone_name as MilestoneName,
    description as Description,
    sequence_no as SequenceNo,
    due_date as DueDate,
    status as Status,
    created_by as CreatedBy,
    created_at as CreatedAt,
    local_last_changed_by as LocalLastChangedBy,
    local_last_changed_at as LocalLastChangedAt,
    last_changed_at as LastChangedAt,
    
    _Project,
    _Task
}
