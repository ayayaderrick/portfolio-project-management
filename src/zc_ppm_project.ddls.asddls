@Metadata.allowExtensions: true
@Metadata.ignorePropagatedAnnotations: true
@Endusertext: {
  Label: '###GENERATED Core Data Service Entity'
}
@Objectmodel: {
  Sapobjectnodetype.Name: 'ZPPM_PROJECT_A'
}
@AccessControl.authorizationCheck: #MANDATORY
define root view entity ZC_PPM_PROJECT
  provider contract TRANSACTIONAL_QUERY
  as projection on ZR_PPM_PROJECT
  association [1..1] to ZR_PPM_PROJECT as _BaseEntity on $projection.PROJECTUUID = _BaseEntity.PROJECTUUID
{
  key ProjectUUID,
  ProjectID,
  ProjectName,
  Description,
  StartDate,
  EndDate,
  Status,
  @Semantics: {
    User.Createdby: true
  }
  CreatedBy,
  @Semantics: {
    Systemdatetime.Createdat: true
  }
  CreatedAt,
  @Semantics: {
    User.Localinstancelastchangedby: true
  }
  LocalLastChangedBy,
  @Semantics: {
    Systemdatetime.Localinstancelastchangedat: true
  }
  LocalLastChangedAt,
  @Semantics: {
    Systemdatetime.Lastchangedat: true
  }
  LastChangedAt,
  _BaseEntity
}
