/// Activity profiles: what the user picks, and what the recorder does with it.
///
/// Two levels, though the split is now thinner than it was:
///
///  * [ActivityTypeEntity] is the *label* — what the user chose, what the
///    activity list shows, what a GPX export carries.
///  * [MovementProfileEntity] is the *behaviour* — how fast the thing plausibly
///    moves and how often it is worth asking the GNSS chip.
///
/// This started at 25 types over 10 profiles, modelled on the public
/// taxonomies (Strava groups sports into foot/cycle/water/winter/other, Health
/// Connect enumerates ~60 exercise types, OsmAnd ships car/bike/walk/boat/
/// aircraft/train). That was the wrong instinct, for a reason specific to how
/// this data is stored: drift's `textEnum` keeps the enum *name* in a plain
/// TEXT column with no CHECK constraint, so **adding** a value costs no
/// migration at all, while **removing** one strands every stored row that
/// holds it. Cheap to add, expensive to remove — so the right starting point
/// is the smallest set that is certainly needed, extended on demand.
///
/// Fourteen of the original types were also pure labels: kayak, canoe,
/// paddleboard and rowing produced a bit-identical recording, as did the three
/// snow sports and the three motor types. Twenty-five choices yielded ten
/// behaviours, at six mapping sites per entry.
///
/// The type/profile split therefore now maps almost one-to-one, and its
/// remaining value is forward-looking: a future "mountain bike" or "trail run"
/// label attaches to an existing profile without inventing new constants.
///
/// Both sit below every capability: recording, preferences and the map all
/// need this vocabulary, and none of them may depend on another.
library;

export 'src/activity_profile.dart';
