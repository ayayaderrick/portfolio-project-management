@AccessControl.authorizationCheck: #MANDATORY
@Metadata.allowExtensions: true
@ObjectModel.sapObjectNodeType.name: 'ZPPM_PROJECT_A'
@EndUserText.label: '###GENERATED Core Data Service Entity'
define root view entity ZR_PPM_PROJECT
  as select from zppm_project_a as Project
  composition [0..*] of ZR_PPM_MILESTONE     as _Milestone
  association [0..1] to ZI_PPM_TASKAGGREGATE as _TaskAggregate on $projection.ProjectUUID = _TaskAggregate.ProjectUUID
{
  key project_uuid          as ProjectUUID,
      project_id            as ProjectID,
      project_name          as ProjectName,
      description           as Description,
      start_date            as StartDate,
      end_date              as EndDate,
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

      _Milestone,
      _TaskAggregate
}
