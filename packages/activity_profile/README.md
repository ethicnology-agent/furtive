# activity_profile

What the user is doing, and what the recorder should do about it.

## When to use it

Whenever a module needs to know what kind of activity a recording is, or how
that kind behaves. Recording reads the tuning to configure the GNSS stream,
the quality filter reads it to decide what a plausible fix looks like,
preferences stores the last type chosen, and the map shows it. None of those
may depend on another, so the vocabulary sits below all of them.

Keep presentation out. Which types exist and which may be chosen is
vocabulary; which icon or translated label stands for one is the business of
whatever renders it.

## Example

```dart
final profile = type.movementProfile;
final interval = profile.tuning.intervalFor(RecordingDetailEntity.balanced);

if (!profile.tuning.acceptsAccuracy(fix.accuracy)) return; // too vague
```

## Owned and borrowed

Owned: `ActivityTypeEntity`, `MovementProfileEntity`, `RecordingDetailEntity`,
`NavigationKind`, `MovementTuning`, and `selectableActivityTypes`. Nothing is
borrowed; the module holds no resource, reaches no platform and has no
lifecycle.

## Guarantees

The taxonomy is deliberately short. drift's `textEnum` stores the enum *name*
in a plain TEXT column with no CHECK constraint, so **adding** a value costs
no migration while **removing** one strands every stored row that holds it.
Cheap to add, expensive to remove — a test keeps the count under ten as a
tripwire, not a law.

`unknown` exists for rows that predate the taxonomy and for imports, and is
never offered as a choice. `other` is permissive enough to cover a kayak, a
ski run or a train, which is what makes the short list safe.

`plausibleSpeedMps` is not a rejection ceiling. Exceeding it makes a fix
suspicious, and the quality filter re-anchors after a few consecutive
suspicions, so a genuinely fast vehicle can never be filtered into silence.
`acceptsAccuracy(null)` is true: a missing estimate means the provider did
not report quality, not that it reported poor quality.

`RecordingDetailEntity` is an intent, not a number of seconds. iOS exposes no
interval knob and Android's is a requested rate it may miss, so a literal
interval would promise what no platform guarantees.

## Verification

`test/activity_profile_test.dart` covers the taxonomy and its tripwire, that
`unknown` is never selectable and `other` is permissive, the speed ceilings
against real motorway and world-record swim speeds, accuracy tolerance
including the null case, how detail scales the profile interval, and the
platform navigation kind each profile asks for.
