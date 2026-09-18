#!/usr/bin/env bash
# The pull. The magnitude floor, the date window and the bounding box are all sampling decisions,
# and they are the first thing the other side will look at, so they are recorded here rather than
# assumed.
#
# California, because the trap is sharpest where the instrument network changed most. Worldwide at
# this magnitude is 130 MB and two million rows, which is neither a laptop dataset nor a clearer
# question.
#
# RECORD-AS: curl USGS fdsnws event query format=csv minmagnitude=3 1970-2025 lat 32..42 lon -125..-114
set -euo pipefail
cd "$(dirname "$0")/../.."
OUT=data/quakes.csv
mkdir -p data
: > "$OUT"
first=1

# A year at a time: the API refuses any single query matching more than 20 000 events, and the
# whole window sits close enough to that ceiling that asking for it in one go is a gamble. Every
# year in the range is fetched whole, so the chunking changes nothing about what is in the file.
for y in $(seq 1970 2025); do
  curl -sS --fail -G "https://earthquake.usgs.gov/fdsnws/event/1/query" \
    --data-urlencode "format=csv" \
    --data-urlencode "starttime=${y}-01-01" \
    --data-urlencode "endtime=$((y + 1))-01-01" \
    --data-urlencode "minmagnitude=3" \
    --data-urlencode "minlatitude=32"    --data-urlencode "maxlatitude=42" \
    --data-urlencode "minlongitude=-125" --data-urlencode "maxlongitude=-114" \
    --data-urlencode "orderby=time-asc" \
    -o "/tmp/q.$$" || { echo "USGS query for $y failed" >&2; exit 1; }
  if [ "$first" = 1 ]; then cat "/tmp/q.$$" >> "$OUT"; first=0
  else tail -n +2 "/tmp/q.$$" >> "$OUT"; fi
  rm -f "/tmp/q.$$"
  printf '.' >&2
done
printf '\n' >&2
echo "$OUT"
