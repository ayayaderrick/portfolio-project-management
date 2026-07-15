@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Project Task Aggregation'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_PPM_TASKAGGREGATE
  as select from zppm_task_a      as Task
    inner join   zppm_milestone_a as Milestone on Task.milestone_uuid = Milestone.milestone_uuid
{
  key Milestone.project_uuid as ProjectUUID,
      count( * )             as ProjectTaskCount,
      sum(
          case
              when Task.status = 'DON'
              then 1
              else 0
          end
      )                      as ProjectCompletedTaskCount
}
group by
  Milestone.project_uuid
