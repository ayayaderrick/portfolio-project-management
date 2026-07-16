@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Milestone Status Value Help'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_PPM_MILESTONESTATUS_VH
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
      CodeType = 'MILESTONE_STATUS'
  and Active   = 'X'
