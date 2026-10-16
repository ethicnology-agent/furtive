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
///
/// Written as the download runs rather than only when it finishes. The first
/// version recorded at completion alone, which meant an interrupted download
/// left an area on the list with nothing beside it and a storage total that
/// accounted for none of the megabytes it had just written.
class OfflineLedger {
  OfflineLedger(this._file);

  final File _file;

  /// Every write happens after the one before it.
  ///
  /// Progress is recorded while a download runs, completion records again,
  /// and a refresh prunes rows — all read-modify-write, and all able to
  /// overlap. Interleaved, a stale snapshot could be written back over a
  /// newer one.
  Future<void> _queue = Future<void>.value();

  Future<void> _serialise(Future<void> Function() work) {
    final next = _queue.then((_) => work());
    // Keep the chain alive: an entry that threw must not stop later ones,
    // and _write already swallows its own failures.
    _queue = next.catchError((Object _) {});
    return next;
  }

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

  Future<void> record(String key, OfflineAreaCost cost) {
    if (key.isEmpty) return Future<void>.value();
    return _serialise(() async {
      final entries = await read()
        ..[key] = cost;
      await _write(entries);
    });
  }

  /// Drops the rows for areas that are no longer on the device.
  ///
  /// Called with the keys that survive rather than the ones removed, because
  /// a region deleted by anything else — an older build, a future screen —
  /// would otherwise leave its cost counted forever.
  Future<void> retainOnly(Set<String> keys) => _serialise(() async {
    final entries = await read();
    final kept = {
      for (final entry in entries.entries)
        if (keys.contains(entry.key)) entry.key: entry.value,
    };
    if (kept.length == entries.length) return;
    await _write(kept);
  });

  /// Writes beside the ledger and renames over it.
  ///
  /// `writeAsString` truncates in place, so a process killed mid-write — the
  /// case this file exists to survive, since it is written every few seconds
  /// during a download — left a half-written file that reads as empty and
  /// took every area's accounting with it. A rename on the same directory is
  /// atomic, so the ledger is either the old one or the new one.
  Future<void> _write(Map<String, OfflineAreaCost> entries) async {
    final temporary = File('${_file.path}.tmp');
    try {
      await temporary.writeAsString(
        jsonEncode({
          for (final entry in entries.entries) entry.key: entry.value.toJson(),
        }),
        flush: true,
      );
      await temporary.rename(_file.path);
    } on Object {
      // Losing the accounting is not worth failing a finished download over.
      try {
        if (temporary.existsSync()) temporary.deleteSync();
      } on Object {
        // Nothing further to try.
      }
    }
  }
}

/// What one area cost to download, and whether that download finished.
class OfflineAreaCost {
  const OfflineAreaCost({
    required this.tiles,
    required this.bytes,
    this.expected = 0,
    this.complete = true,
  });

  final int tiles;
  final int bytes;

  /// How many the whole area needs, as the renderer counted them while the
  /// download ran. Zero for a row written before this was recorded, and for
  /// one written before the renderer had finished counting.
  ///
  /// Kept so an unfinished area can say how far it got. The count cannot be
  /// recovered afterwards — nothing reports it once the download is over —
  /// and recomputing it here would need the area's bounds, which come back
  /// from the platform as doubles.
  final int expected;

  /// How much of the area is on the device, or null when the total is not
  /// known.
  double? get fraction {
    if (expected <= 0) return null;
    return (tiles / expected).clamp(0.0, 1.0);
  }

  /// False while a download is still running, and for one that was cut
  /// short. An area is listed either way — the renderer keeps the tiles it
  /// already fetched — so the screen has to be able to say which it is.
  final bool complete;

  Map<String, Object?> toJson() => {
    'tiles': tiles,
    'bytes': bytes,
    'expected': expected,
    'complete': complete,
  };

  /// Null for anything that is not a well-formed entry, so one bad row
  /// cannot be read as a zero and silently lower the total.
  static OfflineAreaCost? tryParse(Object? value) {
    if (value is! Map) return null;
    final tiles = value['tiles'];
    final bytes = value['bytes'];
    if (tiles is! int || bytes is! int) return null;
    if (tiles < 0 || bytes < 0) return null;
    // Rows written before downloads were recorded as they ran carry no
    // flag, and only ever existed for finished downloads.
    final complete = value['complete'];
    final expected = value['expected'];
    return OfflineAreaCost(
      tiles: tiles,
      bytes: bytes,
      expected: expected is int && expected >= 0 ? expected : 0,
      complete: complete is bool ? complete : true,
    );
  }
}
