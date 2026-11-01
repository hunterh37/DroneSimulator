#!/bin/zsh
# Host driver for DemoDirector (visionOS simulator).
#   demo.sh launch <script|live> [hideui]   build-free relaunch with env
#   demo.sh cmd '<json op or array>'        live command
#   demo.sh state                           print state.json
#   demo.sh rec start <out.mov> | rec stop  simulator screen recording
#   demo.sh shot <out.png>                  screenshot
set -e
BUNDLE=${BUNDLE:-org.dicyaninlabs.DroneArena}
DEV=${DEV:-booted}
data() { xcrun simctl get_app_container $DEV $BUNDLE data; }
case $1 in
  launch)
    xcrun simctl terminate $DEV $BUNDLE 2>/dev/null || true
    if [[ $2 == live ]]; then export SIMCTL_CHILD_DEMO_LIVE=1; else export SIMCTL_CHILD_DEMO_SCRIPT=$2; fi
    [[ $3 == hideui ]] && export SIMCTL_CHILD_DEMO_HIDEUI=1
    xcrun simctl launch $DEV $BUNDLE ;;
  cmd)
    d=$(data)/Documents/demo; mkdir -p $d; print -r -- "$2" > $d/cmd.tmp && mv $d/cmd.tmp $d/cmd.json ;;
  script)
    d=$(data)/Documents/demo/scripts; mkdir -p $d; cp "$2" $d/ ;;
  state) cat $(data)/Documents/demo/state.json ;;
  rec)
    if [[ $2 == start ]]; then
      xcrun simctl io $DEV recordVideo --codec=h264 --force "$3" & echo $! > /tmp/demo_rec.pid
    else
      kill -INT $(cat /tmp/demo_rec.pid); sleep 2
    fi ;;
  shot) xcrun simctl io $DEV screenshot "$2" ;;
  *) sed -n 2,8p $0 ;;
esac
