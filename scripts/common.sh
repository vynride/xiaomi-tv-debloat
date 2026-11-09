#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 vynride
# Shared helpers. Source this file, don't run it directly.
#
# Set TV_HOST to your TV's IP (port 5555 is assumed) or ANDROID_SERIAL to a full adb serial.
#   export TV_HOST=192.168.1.50

if [ -z "${ANDROID_SERIAL:-}" ]; then
  if [ -z "${TV_HOST:-}" ]; then
    echo "error: set TV_HOST=<tv-ip> (or ANDROID_SERIAL=<ip:port>)" >&2
    exit 1
  fi
  ANDROID_SERIAL="$TV_HOST:5555"
fi
export ANDROID_SERIAL

# adb shell output can contain \r on older adb versions. Strip it everywhere.
sh_() { adb shell "$@" | tr -d '\r'; }

require_device() {
  adb connect "$ANDROID_SERIAL" >/dev/null 2>&1
  state=$(adb get-state 2>/dev/null | tr -d '\r')
  if [ "$state" != "device" ]; then
    echo "error: $ANDROID_SERIAL is not connected/authorized (state: ${state:-none})." >&2
    echo "  - Is USB debugging enabled on the TV?" >&2
    echo "  - Did you accept the 'Allow USB debugging?' prompt on the TV screen?" >&2
    exit 1
  fi
}

is_installed() { sh_ pm list packages "$1" | grep -qx "package:$1"; }

# Strip comments and blank lines from a list file.
read_list() { sed -e 's/#.*//' -e 's/[[:space:]]*$//' "$1" | grep -v '^$'; }

# Package-manager and appops changes are written to disk lazily (appops can wait
# up to 30 minutes). Rebooting before they're flushed silently loses them.
flush_state() {
  sh_ cmd appops write-settings >/dev/null 2>&1
  echo "waiting 20s for package state to be written to disk..."
  sleep 20
}
