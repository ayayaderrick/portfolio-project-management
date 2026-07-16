@Metadata.allowExtensions: true
@Metadata.ignorePropagatedAnnotations: true
@EndUserText: {
  label: '###GENERATED Core Data Service Entity'
}
@ObjectModel: {
  sapObjectNodeType.name: 'ZPPM_PROJECT_A'
}
@AccessControl.authorizationCheck: #MANDATORY
@Search.searchable: true
define root view entity ZC_PPM_PROJECT
  provider contract transactional_query
  as projection on ZR_PPM_PROJECT
  association [1..1] to ZR_PPM_PROJECT as _BaseEntity on $projection.ProjectUUID = _BaseEntity.ProjectUUID
{
  key ProjectUUID,
      @Search.defaultSearchElement: true
      ProjectID,
      @Search.defaultSearchElement: true
      ProjectName,
      Description,
      StartDate,
      EndDate,
      @Consumption.filter.selectionType: #SINGLE
      @Consumption.valueHelpDefinition: [{
        entity: { name: 'ZI_PPM_PROJECTSTATUS_VH', element: 'Code' }
      }]
      Status,
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
      _BaseEntity,
      _TaskAggregate,
      _Milestone : redirected to composition child ZC_PPM_MILESTONE
}
