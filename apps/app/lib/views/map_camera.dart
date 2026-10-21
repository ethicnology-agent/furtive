/// The zoom levels this application asks a map for.
///
/// They sat on `Global` next to the build number and the device model, which
/// made one class answer both "what is this phone" and "how close does the
/// camera get". They are neither global nor platform facts: they are a
/// product decision about framing, shared by the two screens that draw a
/// track, and the map module takes them as parameters precisely so the
/// application gets to make it.
abstract final class MapCamera {
  static const maxZoom = 18.0;
  static const defaultZoom = 12.0;
}
