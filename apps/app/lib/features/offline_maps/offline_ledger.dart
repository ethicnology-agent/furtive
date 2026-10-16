import 'dart:convert';
import 'dart:io';

/// What each area the user chose to keep actually cost.
///
/// Kept here because the renderer will not say. `OfflineRegion` carries no
/// size and no tile count, and the only moment those numbers exist is the
/// last progress event of the download that produced them — so they are
/// written down then or they are lost.
///
/// A file rather than a table: this is a handful of rows keyed by a string,
/// read once to draw one line of a settings screen, with nothing to query
/// and nothing to migrate. The settings database holds settings, and an
/// accounting of map downloads is not one.
///
/// Entries are keyed by the same identity the region metadata carries, so a
/// download that supersedes an interrupted one replaces its row rather than
/// adding a second.
class OfflineLedger {
  OfflineLedger(this._file);

  final File _file;

  /// Reads the ledger, treating anything unreadable as empty.
  ///
  /// A corrupt or half-written file must not take out the screen that shows
  /// it: the worst honest outcome is a monitor that under-reports, and the
  /// next completed download writes a good file over it.
  Future<Map<String, OfflineAreaCost>> read() async {
    try {
      if (!await _file.exists()) return {};
      final decoded = jsonDecode(await _file.readAsString());
      if (decoded is! Map<String, dynamic>) return {};
      final costs = <String, OfflineAreaCost>{};
      for (final entry in decoded.entries) {
        final cost = OfflineAreaCost.tryParse(entry.value);
        if (cost != null) costs[entry.key] = cost;
      }
      return costs;
    } on Object {
      return {};
    }
  }

  Future<void> record(String key, OfflineAreaCost cost) async {
    if (key.isEmpty) return;
    final entries = await read()
      ..[key] = cost;
    await _write(entries);
  }

  /// Drops the rows for areas that are no longer on the device.
  ///
  /// Called with the keys that survive rather than the ones removed, because
  /// a region deleted by anything else — an older build, a future screen —
  /// would otherwise leave its cost counted forever.
  Future<void> retainOnly(Set<String> keys) async {
    final entries = await read();
    final kept = {
      for (final entry in entries.entries)
        if (keys.contains(entry.key)) entry.key: entry.value,
    };
    if (kept.length == entries.length) return;
    await _write(kept);
  }

  Future<void> _write(Map<String, OfflineAreaCost> entries) async {
    try {
      await _file.writeAsString(
        jsonEncode({
          for (final entry in entries.entries) entry.key: entry.value.toJson(),
        }),
      );
    } on Object {
      // Losing the accounting is not worth failing a finished download over.
    }
  }
}

/// What one area cost to download.
class OfflineAreaCost {
  const OfflineAreaCost({required this.tiles, required this.bytes});

  final int tiles;
  final int bytes;

  Map<String, Object?> toJson() => {'tiles': tiles, 'bytes': bytes};

  /// Null for anything that is not a well-formed entry, so one bad row
  /// cannot be read as a zero and silently lower the total.
  static OfflineAreaCost? tryParse(Object? value) {
    if (value is! Map) return null;
    final tiles = value['tiles'];
    final bytes = value['bytes'];
    if (tiles is! int || bytes is! int) return null;
    if (tiles < 0 || bytes < 0) return null;
    return OfflineAreaCost(tiles: tiles, bytes: bytes);
  }
}
