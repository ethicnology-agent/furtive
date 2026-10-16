"""Regenerates apps/app/lib/features/offline_maps/countries.dart.

Source: Natural Earth 110m admin-0 countries (public domain).
    curl -sLO https://raw.githubusercontent.com/nvkelso/natural-earth-vector/\
master/geojson/ne_110m_admin_0_countries.geojson

Run:
    python3 tool/generate_countries.py ne_110m_admin_0_countries.geojson \
        > apps/app/lib/features/offline_maps/countries.dart
    dart format apps/app/lib/features/offline_maps/countries.dart

The format pass is part of the recipe, not an afterthought: this writes one
entry per line and the formatter reflows them, so output that has not been
formatted will differ from what is committed.

Committed rather than fetched at build time: the picker has to work offline,
the data changes about never, and a build that reaches out to GitHub is not
reproducible.
"""
import json, math, sys

d = json.load(open(sys.argv[1]))

def parts(g):
    t, c = g['type'], g['coordinates']
    return [c[0]] if t == 'Polygon' else [p[0] for p in c]

def ring_area(r):
    if len(r) < 3: return 0.0
    lat0 = math.radians(sum(y for _, y in r) / len(r))
    k = math.cos(lat0)
    a = 0.0
    for i in range(len(r)):
        x1, y1 = r[i]; x2, y2 = r[(i + 1) % len(r)]
        a += (x1 * k) * y2 - (x2 * k) * y1
    return abs(a) / 2

def rbox(r):
    xs = [p[0] for p in r]; ys = [p[1] for p in r]
    return min(xs), min(ys), max(xs), max(ys)

def km_from_box(box, pt):
    w, s, e, n = box; x, y = pt
    dx = 0.0 if w <= x <= e else min(abs(x - w), abs(x - e))
    dy = 0.0 if s <= y <= n else min(abs(y - s), abs(y - n))
    return math.hypot(dx * 111.32 * math.cos(math.radians(y)), dy * 111.32)

# A part joins the box if it is near the main landmass, or if it is a large
# enough piece of the country to be a place people live rather than an
# outlying dependency.
#
# Distance alone was not enough: peninsular Malaysia is 66% of the country's
# largest landmass and sits 833 km from it, so a 500 km rule put Kuala Lumpur
# outside the box while the screen promised a rectangle around Malaysia.
# Share alone would not do either: French Guiana is 16% of metropolitan
# France and 6,879 km away.
NEAR_KM = 500
MAJOR_SHARE = 0.25

def primary_box(feat):
    ps = sorted(parts(feat['geometry']), key=ring_area, reverse=True)
    largest = ring_area(ps[0])
    box = rbox(ps[0])
    for r in ps[1:]:
        b = rbox(r)
        c = ((b[0] + b[2]) / 2, (b[1] + b[3]) / 2)
        near = km_from_box(box, c) <= NEAR_KM
        major = largest > 0 and ring_area(r) / largest >= MAJOR_SHARE
        if near or major:
            box = (min(box[0], b[0]), min(box[1], b[1]),
                   max(box[2], b[2]), max(box[3], b[3]))
    return box

rows = []
for f in d['features']:
    p = f['properties']
    iso = p.get('ISO_A2_EH') or p.get('ISO_A2') or ''
    name = p.get('ADMIN') or p.get('NAME') or ''
    if not iso or iso == '-99' or not name:
        continue
    if name == 'Antarctica':
        continue
    w, s, e, n = primary_box(f)
    if e - w <= 0 or n - s <= 0:
        continue
    rows.append((iso, name, w, s, e, n))

rows.sort(key=lambda r: r[1])
print(f"{len(rows)} countries", file=sys.stderr)
out = sys.stdout
if True:
    out.write(f'''// GENERATED — do not edit by hand. See tool/generate_countries.py.
//
// Bounding boxes for the primary region of each country, from Natural Earth
// 110m admin-0 (public domain, naturalearthdata.com).
//
// "Primary region" rather than the whole country: a box around every piece of
// France would stretch from French Guiana to the Rhine, and a box around
// every piece of Fiji would wrap the planet. So each box covers the
// country's largest landmass, plus any part that is either within 500 km of
// it or at least a quarter of its size.
//
// Both halves of that are needed. Distance alone put Kuala Lumpur outside
// Malaysia, because the peninsula is 66% of the country's largest landmass
// and sits 833 km from it. Share alone would have pulled in French Guiana,
// which is 16% of metropolitan France and 6,879 km away. Together they keep
// Corsica with France and Northern Ireland with the United Kingdom, and
// leave out Hawaii and the Canaries.
//
// Names are English, as Natural Earth records them. They are not translated:
// the application ships 26 locales and no translated country list, and a
// half-translated picker reads worse than a consistently English one.
''')
    out.write('\nimport \'package:geo/geo.dart\';\n\n')
    out.write('/// A country the user can ask to keep, and the box it covers.\n')
    out.write('class Country {\n')
    out.write('  const Country(this.code, this.name, this.bounds);\n\n')
    out.write('  /// ISO 3166-1 alpha-2.\n  final String code;\n\n')
    out.write('  final String name;\n\n  final GeoBounds bounds;\n}\n\n')
    out.write('/// Sorted by name, so a picker can show them as they come.\n')
    out.write('const countries = <Country>[\n')
    for iso, name, w, s, e, n in rows:
        esc = name.replace("\\", "\\\\").replace("'", "\\'")
        out.write(f"  Country('{iso}', '{esc}', GeoBounds(west: {w:.2f}, "
                  f"south: {s:.2f}, east: {e:.2f}, north: {n:.2f})),\n")
    out.write('];\n')

