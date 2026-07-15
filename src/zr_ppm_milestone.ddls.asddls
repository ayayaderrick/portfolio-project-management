@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Milestone'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZR_PPM_MILESTONE
  as select from zppm_milestone_a
  association to parent ZR_PPM_PROJECT as _Project on $projection.ProjectUuid = _Project.ProjectUUID
  composition [0..*] of ZR_PPM_TASK    as _Task
{
  key milestone_uuid        as MilestoneUuid,
      project_uuid          as ProjectUuid,
      milestone_id          as MilestoneId,
      milestone_name        as MilestoneName,
      description           as Description,
      sequence_no           as SequenceNo,
      due_date              as DueDate,
      status                as Status,
      @Semantics.user.createdBy: true
      created_by            as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      created_at            as CreatedAt,
      @Semantics.user.localInstanceLastChangedBy: true
      local_last_changed_by as LocalLastChangedBy,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at       as LastChangedAt,

      _Project,
      _Task
}
