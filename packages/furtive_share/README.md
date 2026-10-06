# furtive_share

The live-sharing wire format and its cryptography, identical for the
application that encrypts and the viewer that decrypts.

## When to use it

Whenever something crosses the wire: building a link, deriving a share's
keys, encoding a position, parsing what a relay returned. Both ends of a
share speak this module and nothing else, which is the point — a format
owned by one side is a format the other side guesses at.

It is pure Dart, with `nostr` and `pointycastle` as its only dependencies.
Keep it that way: `tool/check_share_boundary.py` fails the build on an
import that would drag a database, a sensor or Flutter into a read-only
browser viewer whose entire pitch is that it can reach neither. Tree-shaking
is not a defence — it removes unreachable code, not a real import.

## Example

```dart
final keys = deriveShareKeys(shareSecret: secret);  // 32 bytes → topic + keypair
final link = ShareLink(                             // what the observer receives
  publisherPublicKey: publisher.public,
  shareSecret: secret,
  relays: relayUrls,
  passwordProtected: password != null,
).toUri(viewerBase);
```

A password-protected derivation is Argon2id and costs seconds, so the
application runs it through `compute` rather than on the UI isolate.

## Owned and borrowed

Owned: the v1 link format, the key derivation, the event kinds and their
expiration, the point encoding, and the parser that refuses everything else.
Borrowed: nothing. The module holds no storage, no network and no clock.

`SharePointStatus` deliberately duplicates `ActivityPointStatusEntity`
rather than importing it. A rename in a domain layer must not silently
change what goes over the wire: viewers are already-open browser tabs and
links pasted into conversations, and neither can be migrated.

## Guarantees

**No long-term key material exists.** A share's keys are derived from the 32
bytes in its link, live as long as the share, and are regenerated for the
next one. "No identity" is structural here, not a policy — there is nothing
to leak.

**The descriptor lives in the URL fragment.** Browsers neither send it in
the request line nor put it in `Referer`. The format is built around that
single property, and nothing in it may ever move into a query parameter.

**The publisher's public key travels so the viewer can pin `authors`.** That
turns nostr's signature layer into the anti-injection mechanism: a forged
position is never requested, not merely ignored.

**Parsing refuses rather than coerces, and never echoes the offending
value.** Every failure here is attacker-reachable — a relay can return
anything, a link can be hand-edited — and a malformed link may contain key
material in an application that exports its logs.

Live positions use an ephemeral kind, so relays are not expected to store
them. The recent-history snapshot is addressable and bounded, and carries a
NIP-40 expiration: hygiene, not a guarantee, since the NIP is explicit that
relays may keep expired events.

Password-protected shares use Argon2id at the OWASP headline configuration
(m=19456 KiB, t=2, p=1), chosen as the cheapest of the five OWASP considers
equally strong because the viewer runs it in a browser.

The full contract is `docs/SHARE-TRACKING.md`; this module is its
implementation and the two are meant to be read together.

## Verification

79 tests across four files, one per concern: key derivation and its
preconditions, the link round-trip and the malformed links it must refuse,
the payload kinds and expiration, and the wire encoding with the parser's
refusals. The boundary itself is checked by `melos run share-boundary`
rather than by a test, because what it forbids would compile and pass.
