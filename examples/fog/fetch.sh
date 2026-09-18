#!/usr/bin/env bash
# The pull. This is the first node of your lineage: what you asked the API for IS the sampling
# decision, so it is recorded rather than happening quietly before the work starts.
#
# Ten stations, 1990-2025, two indicators. About 5 MB and half a minute.
# Station ids: a spread across Austria, including the two nearest Hallein (131, 145).
#
# RECORD-AS: curl klima-v2-1d nebel,gew 1990-2025 stations 131,145,105,30,35,93,20,80,124,170
set -euo pipefail
cd "$(dirname "$0")/../.."
OUT=data/fog-nebel-gew.csv
mkdir -p data
curl -sS --fail -G "https://dataset.api.hub.geosphere.at/v1/station/historical/klima-v2-1d" \
  --data-urlencode "parameters=nebel" \
  --data-urlencode "parameters=gew" \
  --data-urlencode "start=1990-01-01T00:00" \
  --data-urlencode "end=2025-12-31T00:00" \
  --data-urlencode "station_ids=131,145,105,30,35,93,20,80,124,170" \
  --data-urlencode "output_format=csv" \
  -o "$OUT"
echo "$OUT"
