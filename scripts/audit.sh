#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 vynride
# Read-only health check. Changes nothing. Run this before and after debloating.
#   TV_HOST=192.168.1.50 ./scripts/audit.sh
set -eu
. "$(dirname "$0")/common.sh"
require_device

echo "== Device"
echo "model:    $(sh_ getprop ro.product.model)"
echo "android:  $(sh_ getprop ro.build.version.release) (API $(sh_ getprop ro.build.version.sdk))"
echo "low_ram:  $(sh_ getprop ro.config.low_ram)"

echo; echo "== Memory"
sh_ grep -E 'MemTotal|MemAvailable|SwapTotal|SwapFree' /proc/meminfo

echo; echo "== Storage (/data)"
sh_ df -h /data | tail -1

echo; echo "== CPU snapshot (top 10)"
sh_ top -b -n 1 -m 10 | sed -n '4,15p' | cut -c1-140

echo; echo "== Biggest processes by memory (PSS)"
sh_ dumpsys meminfo | sed -n '/by process/,/by OOM/p' | sed -n '2,21p'

echo; echo "== Home screen"
sh_ cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME | tail -1

echo; echo "== Settings we care about"
for k in window_animation_scale transition_animation_scale animator_duration_scale \
         private_dns_mode private_dns_specifier wifi_scan_always_enabled ble_scan_always_enabled; do
  echo "$k=$(sh_ settings get global "$k")"
done

echo; echo "== Disabled packages"
sh_ pm list packages -d | sed 's/package://' | sort

echo; echo "== User-installed packages"
sh_ pm list packages -3 | sed 's/package://' | sort
