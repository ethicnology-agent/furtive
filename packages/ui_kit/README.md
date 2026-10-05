# ui_kit

The application's theme, and the components more than one screen renders.

## When to use it

Take the theme from here and build screens out of what it exposes. When a
screen needs a component the kit lacks, add it to the kit rather than
assembling one locally: two local assemblies of the same thing drift, which
is the problem this module exists to end — `StatBlock` replaced several
ad hoc stat chips that had each acquired slightly different styling.

Reusability alone is not the test for admission. A component belongs here
when it carries a product decision: `StatBlock`'s two densities and its rule
of one emphasised value per group, `LabeledDropdown`'s deliberate refusal of
the global input decoration. A widget that merely happens to be used twice
belongs with whichever module owns it.

## Example

```dart
MaterialApp(theme: appTheme, home: ...);

StatBlock(icon: Icons.timer, label: 'Duration', value: '12:34');
StatBlock.compact(icon: Icons.straighten, value: '8.2 km', emphasize: true);

LabeledDropdown<String?>(
  value: selected,
  items: const [null, 'en', 'fr'],
  labelFor: (code) => code ?? 'System default',
  onChanged: (code) => setState(() => selected = code),
);
```

## Owned and borrowed

Owned: `appTheme`, the colour and typography constants it is built from, and
the components exported here. Nothing is borrowed; the kit holds no
resource and reaches no capability — it is below every feature so a styling
decision is made once.

Localization is not owned here. Components take the strings they display,
so the module that knows what a label means also owns its translation —
`showActivityTypePicker` receives its title and a `labelFor`, and the
application keeps the mapping from a type to its translated name.

The kit does depend on `activity_profile`, which is a foundation module and
carries no behaviour: an icon for an activity type means the same thing in
every locale, so the mapping belongs with the component while the label
does not.

## Guarantees

`StatBlock.compact` drops the label visually, never from the information: it
is kept in the semantics, because "12:34" read aloud says nothing. Values
render with tabular figures so a column of stats lines up. `emphasize`
recolours the value and nothing else.

`LabeledDropdown` reports `null` when its type argument is nullable, so
"follow the device locale" can be a real selection rather than the absence
of one.

## Verification

`test/stat_block_test.dart` covers both densities, the semantics of the
compact one with and without a label, emphasis, and tabular figures.
`test/labeled_dropdown_test.dart` covers rendering through `labelFor`,
reporting a selection, the nullable case, and the decoration override that
keeps the trigger text legible. `test/activity_type_picker_test.dart` covers
that every selectable type is listed and `unknown` is not, that labels come
from the caller, the title's header semantics, the checked selection,
dismissal, and that every type has an icon.
`test/formatting_test.dart` covers the display helpers.
