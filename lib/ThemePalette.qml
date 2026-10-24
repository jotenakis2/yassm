pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// Green / orange / red from the active Omarchy theme palette. ShellColor only
// exposes foreground/background/accent/urgent, so the ANSI palette is read
// from the same colors.toml file and kept in sync with theme changes.
Singleton {
    id: root

    property color green: "#76946a"
    property color orange: "#c17158"
    property color red: "#a55555"
    property color blue: "#7aa2f7"

    function apply(raw) {
        const values = {};
        const lines = String(raw || "").split("\n");

        for (let i = 0; i < lines.length; i++) {
            const match = lines[i].match(/^\s*([A-Za-z0-9_-]+)\s*=\s*["']?(#[0-9A-Fa-f]{6})/);

            if (match) {
                values[match[1]] = match[2];
            }
        }

        root.green = values.green || values.bright_green || values.color2 || "#76946a";
        root.orange = values.orange || values.yellow || values.bright_yellow || values.color3 || "#c17158";
        root.red = values.red || values.bright_red || values.color1 || ShellColor.urgent;
        root.blue = values.blue || values.bright_blue || values.color4 || "#7aa2f7";
    }

    FileView {
        path: ShellColor.currentThemePath + "/colors.toml"
        watchChanges: true
        printErrors: false

        onLoaded: root.apply(text())
        onFileChanged: reload()
    }
}
