@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Task Status Value Help'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_PPM_TASKSTATUS_VH
  as select from ZI_PPM_CODELIST
{
      @UI.hidden: true
  key CodelistUuid,
      Code,
      SortOrder,

      /* Associations */
      _Text.Description as Description
}

where
      CodeType = 'TASK_STATUS'
  and Active   = 'X'
