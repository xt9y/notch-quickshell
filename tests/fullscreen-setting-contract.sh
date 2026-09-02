#!/usr/bin/env bash
set -euo pipefail

grep -Fq 'property bool showInFullscreen: true' SettingsService.qml
grep -Fq 'NOTCH_FULLSCREEN: showInFullscreen ? "1" : "0"' SettingsService.qml
grep -Fq 'showInFullscreen=%s' SettingsService.qml
grep -Fq 'root.showInFullscreen = root.boolValue(value, true)' SettingsService.qml
grep -Fq 'WlrLayer.Overlay' SettingsService.qml
grep -Fq 'WlrLayer.Top' SettingsService.qml
grep -Fq 'label: "Show in fullscreen apps"' SettingsPanel.qml
grep -Fq 'root.settings.setShowInFullscreen(value)' SettingsPanel.qml

echo 'fullscreen setting contract: ok'
