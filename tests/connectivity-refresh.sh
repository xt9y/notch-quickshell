#!/usr/bin/env bash
set -euo pipefail

file=${1:-ConnectivityPanel.qml}

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }

grep -q 'property bool wifiRefreshLocked:' "$file" || fail 'Wi-Fi refresh lock missing'
grep -q 'property bool bluetoothRefreshLocked:' "$file" || fail 'Bluetooth refresh lock missing'
grep -q 'function reconcileWifiModel' "$file" || fail 'Wi-Fi keyed reconciliation missing'
grep -q 'function reconcileBluetoothModel' "$file" || fail 'Bluetooth keyed reconciliation missing'
grep -q 'Keys.onEscapePressed:' "$file" || fail 'Wi-Fi password Escape cancel missing'

if grep -q 'wifiModel.clear()' "$file"; then
    fail 'Wi-Fi list is still destructively rebuilt'
fi
if grep -q 'bluetoothModel.clear()' "$file"; then
    fail 'Bluetooth list is still destructively rebuilt'
fi

printf 'connectivity refresh contract: ok\n'
