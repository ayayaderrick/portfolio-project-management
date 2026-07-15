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
      Priority,
      @Consumption.filter.selectionType: #SINGLE
      Status,
      DueDate,
      CreatedBy,
      CreatedAt,
      LocalLastChangedBy,
      LocalLastChangedAt,
      LastChangedAt,
      /* Associations */
      _Milestone : redirected to parent ZC_PPM_MILESTONE

}
