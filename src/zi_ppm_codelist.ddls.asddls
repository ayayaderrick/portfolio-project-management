@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Code List'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZI_PPM_CODELIST
  as select from zppm_codelist
  association [0..*] to ZI_PPM_CODELISTTEXT as _Text on $projection.CodelistUuid = _Text.CodelistUuid
{
  key codelist_uuid         as CodelistUuid,
      code_type             as CodeType,
      @ObjectModel.text.association: '_Text'
      code                  as Code,
      active                as Active,
      sort_order            as SortOrder,
      @Semantics.user.createdBy: true
      created_by            as CreatedBy,
      @Semantics.systemDateTime.createdAt: true
      created_at            as CreatedAt,
      @Semantics.user.localInstanceLastChangedBy: true
      local_last_changed_by as LocalLastChangedBy,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at as LocalLastChangedAt,
      @Semantics.systemDateTime.lastChangedAt: true
      last_changed_at       as LastChangedAt,

      _Text
}
