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
      created_by            as CreatedBy,
      created_at            as CreatedAt,
      local_last_changed_by as LocalLastChangedBy,
      local_last_changed_at as LocalLastChangedAt,
      last_changed_at       as LastChangedAt,

      _Text
}
