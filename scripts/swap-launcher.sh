#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 vynride
# Replace the stock Android TV home screen with an already-installed launcher.
#
#   TV_HOST=192.168.1.50 ./scripts/swap-launcher.sh com.spocky.projengmenu/.ui.home.MainActivity
#
# Install the new launcher FIRST (e.g. from the Play Store). This script refuses to
# disable the stock launcher unless the new one is installed and registered as a HOME app.
#
# Why disable the stock launcher at all? On many Android TV builds the stock launcher
# has a higher intent-filter priority, so `cmd package set-home-activity` reports
# "Success" but Home still opens the stock launcher. Disabling it is the reliable fix.
set -eu
. "$(dirname "$0")/common.sh"

NEW=${1:?usage: swap-launcher.sh <package/.Activity>}
STOCK=${STOCK_LAUNCHER:-com.google.android.tvlauncher/.MainActivity}
NEW_PKG=${NEW%%/*}
STOCK_PKG=${STOCK%%/*}
require_device

if ! is_installed "$NEW_PKG"; then
  echo "error: $NEW_PKG is not installed. Install it first." >&2; exit 1
fi
if ! sh_ cmd package query-activities --brief -a android.intent.action.MAIN \
       -c android.intent.category.HOME | grep -q "$NEW_PKG/"; then
  echo "error: $NEW_PKG does not register a HOME activity." >&2; exit 1
fi

echo "Rollback command (save this):"
echo "  adb shell pm enable $STOCK_PKG && adb shell cmd package set-home-activity $STOCK && adb shell input keyevent KEYCODE_HOME"
echo

sh_ cmd package set-home-activity "$NEW"
sh_ pm disable-user --user 0 "$STOCK_PKG"
sh_ input keyevent KEYCODE_HOME
sleep 8

resumed=$(sh_ dumpsys activity activities | grep -m1 mResumedActivity || true)
case "$resumed" in
  *"$NEW_PKG"*) echo "OK: Home now opens $NEW_PKG" ;;
  *) echo "WARNING: Home did not open $NEW_PKG ($resumed)."
     echo "Rolling back."
     sh_ pm enable "$STOCK_PKG"
     sh_ cmd package set-home-activity "$STOCK"
     sh_ input keyevent KEYCODE_HOME
     exit 1 ;;
esac

flush_state
echo "Reboot (adb reboot) and confirm the new launcher comes up on boot."
