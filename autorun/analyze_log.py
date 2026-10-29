# Where does the time go in a run on the original? usage: analyze_log.py <log> [last chapter prefix]
import re, sys
rows = []
for l in open(sys.argv[1], errors="replace"):
    m = re.match(r"\[\s*(\d+)\] \w+\s+(AUTORUN .*)", l.rstrip("\n"))
    if m:
        rows.append((int(m.group(1)), m.group(2)))
last = sys.argv[2] if len(sys.argv) > 2 else "ch99"
cur = None
chap = None
expired = {}
print("chapter durations")
for t, x in rows:
    m = re.search(r"=== chapter (\w+)", x)
    if m:
        if cur:
            print("  %-28s %6.1f s" % (cur[0], (t - cur[1]) / 1000.0))
        cur = (m.group(1), t)
print("  last started:", cur)
print("waits that ran to their timeout (ms: count)")
for t, x in rows:
    m = re.search(r"Waited (\d+) ms for function: \w+, result: (\w+)", x)
    if m and m.group(2) == "nil":
        expired[int(m.group(1))] = expired.get(int(m.group(1)), 0) + 1
print("  ", sorted(expired.items()))
print("gaps longer than 6 s between two log lines")
prev = None
for t, x in rows:
    m = re.search(r"=== chapter (\w+)", x)
    if m:
        chap = m.group(1)
    if prev and chap and chap <= last and t - prev[0] > 6000:
        print("  %s %5.1f s after [%s] then [%s]" % (chap[:4], (t - prev[0]) / 1000.0, prev[1][8:80], x[8:60]))
    prev = (t, x)
