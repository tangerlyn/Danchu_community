#!/bin/bash
# Simulate a 30-second walk around Yeouido, Seoul
DEVICE="1D74F570-D431-43CD-85AE-B8D135DDD2E4"

echo "🐕 Starting GPS walk simulation..."

declare -a LATS=(37.5283 37.5285 37.5287 37.5289 37.5291 37.5293 37.5295 37.5297 37.5299 37.5301 37.5303 37.5305 37.5307 37.5309 37.5311)
declare -a LNGS=(126.9322 126.9328 126.9335 126.9342 126.9350 126.9358 126.9365 126.9372 126.9380 126.9388 126.9395 126.9402 126.9410 126.9418 126.9425)

for i in "${!LATS[@]}"; do
  echo "📍 Point $((i+1))/15: ${LATS[$i]}, ${LNGS[$i]}"
  xcrun simctl location "$DEVICE" set "${LATS[$i]},${LNGS[$i]}"
  sleep 2
done

echo "✅ Walk simulation complete! (30 seconds, ~800m)"
