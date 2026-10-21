import 'package:flutter/material.dart';

/// Shows [bar], replacing whatever is already on screen rather than queueing
/// behind it.
///
/// A product decision, not a convenience: several independent listeners can
/// fire in the same frame — an error, a tracking gap, a start confirmation —
/// and queued snackbars make the user dismiss a backlog to see the latest
/// thing that happened, which is the one they care about.
void showSingleSnackBar(BuildContext context, SnackBar bar) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(bar);
}
