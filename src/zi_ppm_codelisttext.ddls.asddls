@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Code Text'
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.dataCategory: #TEXT
define view entity ZI_PPM_CODELISTTEXT
  as select from zppm_codelist_t
{
  key codelist_uuid as CodelistUuid,
      @Semantics.language: true
  key language      as Language,
      @Semantics.text: true
      description   as Description
}
