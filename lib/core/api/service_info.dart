/// Common identity for providers shown in the service settings UI.
///
/// Metadata and source providers have different capabilities, but both expose
/// an id and a display name.
abstract interface class ServiceInfo {
  String get id;
  String get displayName;
}
