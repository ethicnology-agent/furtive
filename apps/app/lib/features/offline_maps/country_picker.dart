import 'package:flutter/material.dart';
import 'package:furtive/features/offline_maps/countries.dart';
import 'package:furtive/l10n/app_localizations.dart';

/// Asks which country to keep.
///
/// A searchable list rather than a dropdown: there are 174 of them, and
/// scrolling to Zimbabwe is not a thing to ask of anyone.
Future<Country?> showCountryPicker(BuildContext context) => showDialog<Country>(
  context: context,
  builder: (context) => const _CountryPickerDialog(),
);

class _CountryPickerDialog extends StatefulWidget {
  const _CountryPickerDialog();

  @override
  State<_CountryPickerDialog> createState() => _CountryPickerDialogState();
}

class _CountryPickerDialogState extends State<_CountryPickerDialog> {
  String _query = '';

  /// Matches on a prefix of the name or of any word in it, so "united"
  /// finds both United Kingdom and United States, and "kingdom" finds the
  /// first. A contains-anywhere match would put Chad under "ha".
  List<Country> get _matches {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return countries;
    return [
      for (final country in countries)
        if (country.code.toLowerCase() == q ||
            country.name.toLowerCase().split(' ').any((w) => w.startsWith(q)))
          country,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final matches = _matches;
    return AlertDialog(
      title: Text(l10n.offlineCountryPick),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              autofocus: true,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: l10n.offlineCountryPick,
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: matches.length,
                itemBuilder: (context, i) => ListTile(
                  title: Text(matches[i].name),
                  onTap: () => Navigator.of(context).pop(matches[i]),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.btnCancel),
        ),
      ],
    );
  }
}
