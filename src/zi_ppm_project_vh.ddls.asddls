@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Value Help for Project'
@Metadata.ignorePropagatedAnnotations: true
@Search.searchable: true
define view entity ZI_PPM_PROJECT_VH
  as select from ZR_PPM_PROJECT
{
      @UI.hidden: true
  key ProjectUUID,
      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.7
      ProjectID,
      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.7
      ProjectName
}
