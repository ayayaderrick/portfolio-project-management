@Metadata.allowExtensions: true
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Milestones'
@Metadata.ignorePropagatedAnnotations: true
@Search.searchable: true
define view entity ZC_PPM_MILESTONE
  as projection on ZR_PPM_MILESTONE
{
  key MilestoneUuid,
      ProjectUuid,
      @Search.defaultSearchElement: true
      MilestoneId,
      @Search.defaultSearchElement: true
      MilestoneName,
      Description,
      SequenceNo,
      DueDate,
      @Consumption.filter.selectionType: #SINGLE
      @Consumption.valueHelpDefinition: [{
        entity: { name: 'ZI_PPM_MILESTONESTATUS_VH', element: 'Code' }
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
      /* Associations */
      _Project : redirected to parent ZC_PPM_PROJECT,
      _Task    : redirected to composition child ZC_PPM_TASK
}
