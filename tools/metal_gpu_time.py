# Prints each process's GPU busy time from a Metal System Trace: per second and per 60 fps frame,
# and per channel (fragment, vertex). Usage, see docs/performance.md:
#   xcrun xctrace export --input game.trace \
#     --xpath '/trace-toc/run[@number="1"]/data/table[@schema="metal-gpu-intervals"]' > gpu.xml
#   python3 tools/metal_gpu_time.py gpu.xml
import sys, collections
import xml.etree.ElementTree as ET
root = ET.parse(sys.argv[1]).getroot()
seen = {}
def val(e):
    if 'ref' in e.attrib:
        return seen[e.attrib['ref']]
    v = (e.tag, e.text, e.attrib.get('fmt'), e)
    if 'id' in e.attrib:
        seen[e.attrib['id']] = v
    for c in e:  # register nested ids
        val(c)
    return v
rows = []
for row in root.iter('row'):
    cols = [val(c) for c in row]
    def first(tag):
        for t, text, fmt, e in cols:
            if t == tag: return text, fmt, e
        return None, None, None
    start = int(first('start-time')[0]); dur = int(cols[1][1])
    chan = first('gpu-channel-name')[1]
    proc = first('process')[1] or '?'
    rows.append((start, dur, chan, proc))
span = (max(r[0] + r[1] for r in rows) - min(r[0] for r in rows)) / 1e9
by_proc = collections.defaultdict(list)
for r in rows: by_proc[r[3]].append(r)
for proc, rs in sorted(by_proc.items(), key=lambda kv: -sum(r[1] for r in kv[1])):
    iv = sorted((r[0], r[0] + r[1]) for r in rs)
    busy = 0; cs, ce = iv[0]
    for s, e in iv[1:]:
        if s > ce: busy += ce - cs; cs, ce = s, e
        else: ce = max(ce, e)
    busy += ce - cs
    chans = collections.Counter()
    for r in rs: chans[r[2]] += r[1]
    print("%-28s busy %6.2f ms/s = %5.2f ms per 60 fps frame | %s" % (proc[:28], busy / 1e6 / span, busy / 1e6 / span / 60,
          ", ".join("%s %.2f" % (c, v / 1e6 / span / 60) for c, v in chans.most_common(3))))
print("span %.1f s" % span)
