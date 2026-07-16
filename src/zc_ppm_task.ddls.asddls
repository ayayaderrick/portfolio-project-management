@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Tasks'
@Metadata.ignorePropagatedAnnotations: true
@Search.searchable: true
define view entity ZC_PPM_TASK
  as projection on ZR_PPM_TASK
{
  key TaskUuid,
      MilestoneUuid,
      @Search.defaultSearchElement: true
      TaskId,
      @Search.defaultSearchElement: true
      TaskName,
      Description,
      AssignedTo,
      @Consumption.valueHelpDefinition: [{
        entity: { name: 'ZI_PPM_TASKSTATUS_VH', element: 'Code' }
      }]
      Priority,
      @Consumption.filter.selectionType: #SINGLE
      @Consumption.valueHelpDefinition: [{
        entity: { name: 'ZI_PPM_TASKSTATUS_VH', element: 'Code' }
      }]
      Status,
      DueDate,
      @Semantics: {
        user.createdBy: true
      }
      CreatedBy,
      @Semantics: {
        systemDateTime.createdAt: true
      }
      CreatedAt,
      @Semantics: {
        user.localInstanceLastChangedBy: true
      }
      LocalLastChangedBy,
      @Semantics: {
        systemDateTime.localInstanceLastChangedAt: true
      }
      LocalLastChangedAt,
      @Semantics: {
        systemDateTime.lastChangedAt: true
      }
      LastChangedAt,
      /* Associations */
      _Milestone : redirected to parent ZC_PPM_MILESTONE

}
