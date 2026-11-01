#!/bin/zsh
# Pulls DroneArena session logs (Documents/DroneLogs) from the paired Vision Pro.
# Usage: scripts/pull-drone-logs.sh [device-udid]   -> notes/drone-logs/<udid>/
set -e
DEV=${1:-$(xcrun devicectl list devices 2>/dev/null | awk '/Apple Vision Pro/ && /physical/ && /available/ {for(i=1;i<=NF;i++) if($i ~ /^[0-9A-F]{8}-[0-9A-F]{16}$/) print $i; exit}')}
[ -z "$DEV" ] && { echo "blocked: no available Vision Pro (wake it, same network or USB-C strap)"; exit 1; }
OUT="$(cd "$(dirname "$0")/.." && pwd)/notes/drone-logs/$DEV"
mkdir -p "$OUT"
xcrun devicectl device copy from --device "$DEV" \
  --domain-type appDataContainer --domain-identifier org.dicyaninlabs.DroneArena \
  --source Documents/DroneLogs --destination "$OUT" >/dev/null
ls -t "$OUT"/**/*.log(N) | head -5
echo "latest: $(ls -t "$OUT"/**/*.log(N) | head -1)"
