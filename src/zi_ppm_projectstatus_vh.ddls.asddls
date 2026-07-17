@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Project Status Value Help'
@Metadata.ignorePropagatedAnnotations: true
@Search.searchable: true
@ObjectModel : { resultSet.sizeCategory: #XS }
define view entity ZI_PPM_PROJECTSTATUS_VH
  as select from ZI_PPM_CODELIST
{
      @UI.hidden: true
  key CodelistUuid,
      @Search.defaultSearchElement: true
      Code,
      SortOrder,

      /* Associations */
      @Search.defaultSearchElement: true
      _Text.Description as Description
}
where
      CodeType = 'PROJECT_STATUS'
  and Active   = 'X'
