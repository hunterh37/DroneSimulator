#!/bin/zsh
# Records one DemoDirector script per clip from the booted visionOS simulator.
#   record_demo.sh <outdir> <script[:seconds[:hideui]]>...
#   e.g. record_demo.sh footage freeflight:26 race:48:hideui safari:40:hideui crate:45:hideui
# Writes <outdir>/<script>.mov and <outdir>/<script>.state.json (marks for editing).
set -e
HERE=${0:A:h}
OUT=$1; shift; mkdir -p $OUT
reset_camera() {
  osascript -e 'tell application "Simulator" to activate' \
    -e 'tell application "System Events" to tell process "Simulator" to click menu item "Reset Camera" of menu "Device" of menu bar 1' >/dev/null
}
for spec in "$@"; do
  name=${spec%%:*}; rest=${spec#*:}; secs=${rest%%:*}; [[ $secs == $name ]] && secs=40
  [[ $spec == *hideui* ]] && hide=hideui || hide=
  reset_camera; sleep 1
  $HERE/demo.sh launch $name $hide >/dev/null
  sleep 6   # app + immersive space boot
  xcrun simctl io booted recordVideo --codec=h264 --force $OUT:A/$name.mov & pid=$!
  sleep $secs
  kill -INT $pid; wait $pid 2>/dev/null || true
  $HERE/demo.sh state > $OUT/$name.state.json || true
  echo "$name: $(ffprobe -v error -show_entries format=duration -of csv=p=0 $OUT/$name.mov)s"
done
