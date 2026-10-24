pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import "lib" as Yassm

BarWidget {
    id: root

    moduleName: "io.github.jotenakis2.yassm"

    readonly property string detectScriptPath: Qt.resolvedUrl("detect-gpu.sh").toString().replace("file://", "")

    readonly property int gpuIntervalMs: 10000

    property var gpu: null

    property string hoveredSegment: ""

    property string gpuKind: "none"
    property string gpuPath: ""
    property string gpuCommand: ""

    property bool showCpu: setting("showCpu", true)
    property bool showMemory: setting("showMemory", true)
    property bool showSwap: setting("showSwap", true)
    property bool showGpu: setting("showGpu", true)
    property bool showBattery: setting("showBattery", true)
    property bool showNet: setting("showNet", true)
    property bool showTemp: setting("showTemp", true)
    property bool showLoad: setting("showLoad", true)
    property bool showDisk: setting("showDisk", true)
    property bool showColors: setting("showColors", true)

    readonly property string iconCpu: String.fromCodePoint(0xF0EE0)
    readonly property string iconMemory: String.fromCodePoint(0xF035B)
    readonly property string iconSwap: String.fromCodePoint(0xF04E2)
    readonly property string iconGpu: String.fromCodePoint(0xF08AE)
    readonly property string iconBatteryFull: String.fromCodePoint(0xF0079)
    readonly property string iconBatteryEmpty: String.fromCodePoint(0xF008E)
    readonly property string iconBatteryPlug: String.fromCodePoint(0xF06A5)
    readonly property string iconNetDown: String.fromCodePoint(0xF01DA)
    readonly property string iconNetUp: String.fromCodePoint(0xF0552)
    readonly property string iconTemp: String.fromCodePoint(0xF050F)
    readonly property string iconTempCool: String.fromCodePoint(0xF1A71)
    readonly property string iconTempWarm: String.fromCodePoint(0xF0510)
    readonly property string iconTempHot: String.fromCodePoint(0xF0E01)
    readonly property string iconLoad: String.fromCodePoint(0xF04C5)
    readonly property string iconDisk: String.fromCodePoint(0xF02CA)

    // Nerd Fonts stores the charging levels on non-contiguous codepoints, so
    // they cannot be derived from a single base like the plain battery icons.
    readonly property var batteryChargingIcons: [
        0xF089C, // charging-10
        0xF0086, // charging-20
        0xF0087, // charging-30
        0xF0088, // charging-40
        0xF089D, // charging-50
        0xF0089, // charging-60
        0xF089E, // charging-70
        0xF008A, // charging-80
        0xF008B, // charging-90
        0xF0085  // charging-100
    ]

    // Plain battery icons run from 0xF007A (battery-10) to 0xF0082
    // (battery-90); 0xF0079 is the complete battery.
    function batteryLevel(percent) {
        const value = Number(percent);

        if (!Number.isFinite(value) || value <= 0) {
            return 0;
        }

        return Math.min(10, Math.max(1, Math.ceil(value / 10)));
    }

    function batteryLevelIcon(percent) {
        const level = batteryLevel(percent);

        if (level === 0) {
            return iconBatteryEmpty;
        }

        if (level === 10) {
            return iconBatteryFull;
        }

        return String.fromCodePoint(0xF0079 + level);
    }

    function batteryChargingIcon(percent) {
        const level = Math.max(1, batteryLevel(percent));
        return String.fromCodePoint(batteryChargingIcons[level - 1]);
    }

    function batteryIcon(percent, status, plugged) {
        if (status === "Charging") {
            return batteryChargingIcon(percent);
        }

        const icon = batteryLevelIcon(percent);

        // A plug next to the battery distinguishes "plugged in but idle"
        // (full or charge threshold reached) from running on battery.
        return plugged ? icon + iconBatteryPlug : icon;
    }

    function makeSegment(key, icon, value, suffix, kind) {
        const valueText = pad(value) + suffix;
        return {
            key: key,
            icon: icon,
            valueText: valueText,
            text: icon + " " + valueText,
            value: value,
            kind: kind
        };
    }

    readonly property var segmentCache: {
        const metrics = Yassm.SystemMetrics;
        const segments = [];

        if (showCpu) {
            segments.push(makeSegment("cpu", iconCpu, Math.round(metrics.cpuPercent), "%", "percent"));
        }

        if (showLoad) {
            segments.push(makeSegment("load", iconLoad, Math.round(metrics.loadPercent), "%", "load"));
        }

        if (showGpu) {
            segments.push(makeSegment("gpu", iconGpu, gpu === null ? null : Math.round(gpu), "%", "percent"));
        }

        if (showMemory) {
            segments.push(makeSegment("memory", iconMemory, Math.round(metrics.memoryPercent), "%", "percent"));
        }

        if (showSwap && metrics.hasSwap) {
            segments.push(makeSegment("swap", iconSwap, Math.round(metrics.swapPercent), "%", "percent"));
        }

        if (showDisk) {
            segments.push(makeSegment("disk", iconDisk, Math.round(metrics.diskPercent), "%", "percent"));
        }

        if (showNet && metrics.hasNetwork) {
            const down = metrics.networkRxKib;
            const up = metrics.networkTxKib;
            const downText = formatRate(down);
            const upText = formatRate(up);

            segments.push({
                key: "net",
                icon: iconNetDown,
                valueText: downText,
                text: iconNetDown + " " + downText + "  " + iconNetUp + " " + upText,
                value: Math.round(down),
                kind: "net",
                secondaryIcon: "  " + iconNetUp,
                secondaryValueText: " " + upText,
                secondaryValue: Math.round(up)
            });
        }

        if (showBattery && metrics.hasBattery) {
            segments.push(makeSegment(
                "battery",
                root.batteryIcon(
                    metrics.batteryPercent,
                    metrics.batteryStatus,
                    metrics.batteryPlugged
                ),
                Math.round(metrics.batteryPercent),
                "%",
                "battery"
            ));
        }

        if (showTemp) {
            segments.push(makeSegment(
                "temp",
                root.temperatureIcon(metrics.hasTemperature ? metrics.temperatureC : null),
                metrics.hasTemperature ? Math.round(metrics.temperatureC) : null,
                "°C",
                "temp"
            ));
        }

        return segments;
    }

    readonly property string displayText: {
        const segments = segmentCache;

        if (segments.length === 0) {
            return "No module enabled";
        }

        return segments.map(function(segment) {
            return segment.text;
        }).join("  ");
    }

    readonly property var segmentOrder: ["cpu", "load", "gpu", "memory", "swap", "disk", "net", "battery", "temp"]

    readonly property var segmentMap: {
        const map = {};
        const segments = segmentCache;

        for (let i = 0; i < segments.length; i++) {
            map[segments[i].key] = segments[i];
        }

        return map;
    }

    function segmentIcon(key) {
        return segmentMap[key] ? segmentMap[key].icon : "";
    }

    function segmentValue(key) {
        return segmentMap[key] ? segmentMap[key].valueText : "";
    }

    function segmentSecondaryIcon(key) {
        return segmentMap[key] && segmentMap[key].secondaryIcon
            ? segmentMap[key].secondaryIcon : "";
    }

    function segmentSecondaryValue(key) {
        return segmentMap[key] && segmentMap[key].secondaryValueText
            ? segmentMap[key].secondaryValueText : "";
    }

    function segmentSecondaryColor(key) {
        if (!root.showColors) {
            return button.foreground;
        }

        const segment = segmentMap[key];

        if (!segment || segment.secondaryValue === undefined) {
            return button.foreground;
        }

        return networkColor(segment.secondaryValue);
    }

    function segmentVisible(key) {
        return segmentMap[key] !== undefined;
    }

    function segmentIconColor(key) {
        if (!root.showColors) {
            return button.foreground;
        }

        if (key !== "battery") {
            return button.foreground;
        }

        const metrics = Yassm.SystemMetrics;

        // On mains power, charging or held at a charge threshold, the battery
        // icon and value both use the theme blue.
        if (metrics.batteryPlugged) {
            return Yassm.ThemePalette.blue;
        }

        return button.foreground;
    }

    function segmentColor(key) {
        if (!root.showColors) {
            return button.foreground;
        }
        const segment = segmentMap[key];

        if (!segment || segment.value === null || !Number.isFinite(segment.value)) {
            return button.foreground;
        }

        if (segment.kind === "battery") {
            return batteryColor(segment.value);
        }

        if (segment.kind === "load") {
            return loadColor(segment.value);
        }

        if (segment.kind === "net") {
            return networkColor(segment.value);
        }

        if (segment.kind === "temp") {
            return temperatureColor(segment.value);
        }

        return percentColor(segment.value);
    }

    function percentColor(value) {
        if (!Number.isFinite(value) || value < 10) {
            return button.foreground;
        }

        if (value < 33) {
            return Yassm.ThemePalette.green;
        }

        if (value < 66) {
            return Yassm.ThemePalette.orange;
        }

        return Yassm.ThemePalette.red;
    }

    function loadColor(value) {
        // Load is not a utilization ratio: it is the run-queue length, so it
        // may legitimately exceed 100 % on an oversubscribed machine.
        if (!Number.isFinite(value)) {
            return button.foreground;
        }

        if (value > 90) {
            return Yassm.ThemePalette.red;
        }

        if (value > 50) {
            return Yassm.ThemePalette.orange;
        }

        if (value > 10) {
            return Yassm.ThemePalette.green;
        }

        return button.foreground;
    }

    function networkColor(value) {
        const kib = Number(value);

        if (!Number.isFinite(kib) || kib < 10) {
            return button.foreground;
        }

        if (kib < 500) {
            return Yassm.ThemePalette.green;
        }

        if (kib <= 1000) {
            return Yassm.ThemePalette.orange;
        }

        return Yassm.ThemePalette.red;
    }

    function batteryColor(value) {
        if (Yassm.SystemMetrics.batteryPlugged) {
            return Yassm.ThemePalette.blue;
        }

        if (!Number.isFinite(value)) {
            return button.foreground;
        }

        if (value < 10) {
            return Yassm.ThemePalette.red;
        }

        if (value < 20) {
            return Yassm.ThemePalette.orange;
        }

        if (value < 50) {
            return Yassm.ThemePalette.green;
        }

        return button.foreground;
    }

    function temperatureIcon(celsius) {
        if (celsius === null || celsius === undefined) {
            return iconTemp;
        }

        const value = Number(celsius);

        if (!Number.isFinite(value)) {
            return iconTemp;
        }

        if (value < 40) {
            return iconTempCool;
        }

        if (value < 50) {
            return iconTemp;
        }

        if (value < 60) {
            return iconTempWarm;
        }

        return iconTempHot;
    }

    function temperatureColor(value) {
        if (!Number.isFinite(value) || value < 40) {
            return button.foreground;
        }

        if (value < 50) {
            return Yassm.ThemePalette.green;
        }

        if (value < 60) {
            return Yassm.ThemePalette.orange;
        }

        return Yassm.ThemePalette.red;
    }

    function pad(value) {
        if (value === null || value === undefined) {
            return " --";
        }

        return String(value).padStart(3, " ");
    }

    function formatLoad(value) {
        const number = Number(value);
        return (Number.isFinite(number) ? number : 0).toFixed(2).padStart(6, " ");
    }

    function formatKibAsGib(kilobytes) {
        const value = Number(kilobytes) / 1048576;
        return (Number.isFinite(value) ? value : 0).toFixed(2) + " GiB";
    }

    // Compact, fixed-width rate for the bar (KiB/s).
    function formatRate(kib) {
        const value = Number(kib);

        if (!Number.isFinite(value) || value <= 0) {
            return "   0K";
        }

        if (value >= 1048576) {
            return (value / 1048576).toFixed(1).padStart(4, " ") + "G";
        }

        if (value >= 1024) {
            return (value / 1024).toFixed(1).padStart(4, " ") + "M";
        }

        return String(Math.round(value)).padStart(4, " ") + "K";
    }

    function formatRateLong(kib) {
        const value = Number(kib);

        if (!Number.isFinite(value) || value <= 0) {
            return "0 KiB/s";
        }

        if (value >= 1048576) {
            return (value / 1048576).toFixed(1) + " GiB/s";
        }

        if (value >= 1024) {
            return (value / 1024).toFixed(1) + " MiB/s";
        }

        return Math.round(value) + " KiB/s";
    }

    function formatKib(kilobytes) {
        const value = Number(kilobytes);

        if (!Number.isFinite(value) || value <= 0) {
            return "0 MiB";
        }

        if (value >= 1048576) {
            return (value / 1048576).toFixed(2) + " GiB";
        }

        return (value / 1024).toFixed(1) + " MiB";
    }

    function formatBytesAsGib(bytes) {
        const value = Number(bytes) / 1073741824;
        return (Number.isFinite(value) ? value : 0).toFixed(2) + " GiB";
    }

    function batteryStateLabel(status) {
        switch (status) {
        case "Charging":
            return "Charging";
        case "Discharging":
            return "Discharging";
        case "Full":
            return "Fully charged";
        case "Not charging":
            return "Not charging";
        default:
            return status || "Unknown";
        }
    }

    function batteryPowerDirection() {
        const status = Yassm.SystemMetrics.batteryStatus;

        if (status === "Discharging") {
            return "draw";
        }

        if (status === "Charging") {
            return "charge";
        }

        return Yassm.SystemMetrics.batteryPlugged ? "charge" : "draw";
    }

    function formatDuration(seconds) {
        const totalMinutes = Math.max(0, Math.round(Number(seconds) / 60));
        const hours = Math.floor(totalMinutes / 60);
        const minutes = totalMinutes % 60;

        if (hours > 0) {
            return hours + "h " + String(minutes).padStart(2, "0") + "m";
        }

        return minutes + "m";
    }

    function tooltipBlock(title, body) {
        const lines = body.split("\n");
        let width = title.length;

        for (let i = 0; i < lines.length; i++) {
            width = Math.max(width, lines[i].length);
        }

        function padLine(line) {
            // NBSP padding keeps every line the same width, so the bar's
            // centered Text lines up their left edges in a monospace font.
            return line.padEnd(width, "\u00A0");
        }

        const padded = [padLine(title.toUpperCase())];

        for (let i = 0; i < lines.length; i++) {
            padded.push(padLine(lines[i]));
        }

        return padded.join("\n");
    }

    function mountsTooltip() {
        const mounts = Yassm.SystemMetrics.mounts;

        if (!mounts || mounts.length === 0) {
            return tooltipBlock("DISK", "Unavailable");
        }

        let targetWidth = 0;
        let usedWidth = 0;
        let totalWidth = 0;
        let percentWidth = 0;
        const rows = [];

        for (let i = 0; i < mounts.length; i++) {
            const target = mounts[i].target;
            const used = formatBytesAsGib(mounts[i].usedBytes);
            const total = formatBytesAsGib(mounts[i].totalBytes);
            const percent = "(" + mounts[i].percent + "%)";

            targetWidth = Math.max(targetWidth, target.length);
            usedWidth = Math.max(usedWidth, used.length);
            totalWidth = Math.max(totalWidth, total.length);
            percentWidth = Math.max(percentWidth, percent.length);
            rows.push({ target: target, used: used, total: total, percent: percent });
        }

        const lines = rows.map(function(row) {
            return row.target.padEnd(targetWidth)
                + "  " + row.used.padStart(usedWidth)
                + " / " + row.total.padStart(totalWidth)
                + " " + row.percent.padStart(percentWidth);
        });

        return tooltipBlock("DISK", lines.join("\n"));
    }

    function moduleTooltip(key) {
        const metrics = Yassm.SystemMetrics;

        if (key === "load") {
            return tooltipBlock(
                "LOAD",
                " 1 min " + formatLoad(metrics.load1) + "\n"
                    + " 5 min " + formatLoad(metrics.load5) + "\n"
                    + "15 min " + formatLoad(metrics.load15)
            );
        }

        if (key === "memory") {
            return tooltipBlock("RAM", formatKibAsGib(metrics.memoryUsedKb) + " / " + formatKibAsGib(metrics.memoryTotalKb));
        }

        if (key === "swap") {
            const swapLine = formatKibAsGib(metrics.swapUsedKb) + " / " + formatKibAsGib(metrics.swapTotalKb);

            if (!metrics.hasZswap) {
                return tooltipBlock("SWAP", swapLine);
            }

            const ratio = metrics.zswapCompressedKb > 0
                ? metrics.zswapOriginalKb / metrics.zswapCompressedKb
                : 0;
            const zswapLine = formatKib(metrics.zswapCompressedKb)
                + " compressed -> " + formatKib(metrics.zswapOriginalKb)
                + " original"
                + (ratio > 0 ? " (" + ratio.toFixed(2) + ":1)" : "");

            return tooltipBlock("SWAP", swapLine + "\nZSWAP\n" + zswapLine);
        }

        if (key === "disk") {
            return mountsTooltip();
        }

        if (key === "cpu") {
            return tooltipBlock("CPU", Math.round(metrics.cpuPercent) + "%");
        }

        if (key === "gpu") {
            return tooltipBlock("GPU", gpu === null ? "Unavailable" : Math.round(gpu) + "%");
        }

        if (key === "net") {
            const metrics = Yassm.SystemMetrics;

            if (!metrics.hasNetwork) {
                return tooltipBlock("NET", "Unavailable");
            }

            const lines = [
                metrics.networkInterface,
                "↓ " + formatRateLong(metrics.networkRxKib),
                "↑ " + formatRateLong(metrics.networkTxKib)
            ];

            return tooltipBlock("NET", lines.join("\n"));
        }

        if (key === "battery") {
            if (!metrics.hasBattery) {
                return tooltipBlock("BATTERY", "Unavailable");
            }

            const lines = [
                Math.round(metrics.batteryPercent) + "% ("
                    + batteryStateLabel(metrics.batteryStatus) + ")"
            ];

            if (metrics.batteryStatus === "Charging" && metrics.batteryTimeToFull > 0) {
                lines.push(formatDuration(metrics.batteryTimeToFull) + " to full");
            } else if (metrics.batteryTimeToEmpty > 0) {
                lines.push(formatDuration(metrics.batteryTimeToEmpty) + " remaining");
            }

            if (Number.isFinite(metrics.batteryPowerW) && Math.abs(metrics.batteryPowerW) >= 0.05) {
                lines.push(
                    Math.abs(metrics.batteryPowerW).toFixed(1) + " W "
                        + batteryPowerDirection()
                );
            }

            return tooltipBlock("BATTERY", lines.join("\n"));
        }

        if (key === "temp") {
            const temperatures = metrics.temperatures;

            if (!temperatures || temperatures.length === 0) {
                return tooltipBlock("TEMPERATURE", "Unavailable");
            }

            const lines = temperatures.map(function(entry) {
                return entry.celsius.toFixed(1).padStart(4, " ")
                    + " °C (" + entry.sensor + ")";
            });

            return tooltipBlock("TEMPERATURE", lines.join("\n"));
        }

        return "";
    }

    function segmentHitAt(x) {
        if (!labelRow || labelRow.width <= 0) {
            return null;
        }

        const origin = labelRow.mapToItem(button, 0, 0);
        const localX = x - origin.x;
        const children = labelRow.children;

        for (let i = 0; i < children.length; i++) {
            const child = children[i];

            if (!child.visible || child.width <= 0) {
                continue;
            }

            if (localX >= child.x && localX <= child.x + child.width) {
                return {
                    key: child.metricKey,
                    center: origin.x + child.x + child.width / 2
                };
            }
        }

        return null;
    }

    function updateTooltip() {
        if (root.opened) {
            root.hideSegmentTooltip();
            return;
        }

        if (!root.bar || !tooltipTracker.containsMouse) {
            root.hideSegmentTooltip();
            return;
        }

        const hit = root.segmentHitAt(tooltipTracker.mouseX);

        if (!hit) {
            root.hideSegmentTooltip();
            return;
        }

        if (root.hoveredSegment === hit.key) {
            return;
        }

        root.hoveredSegment = hit.key;
        tooltipAnchor.x = hit.center - tooltipAnchor.width / 2;
        tooltipAnchor.tooltipHovered = true;
        root.bar.showTooltip(tooltipAnchor, root.moduleTooltip(hit.key));
    }

    function refreshTooltip() {
        root.hoveredSegment = "";
        root.updateTooltip();
    }

    function hideSegmentTooltip() {
        root.hoveredSegment = "";
        tooltipAnchor.tooltipHovered = false;

        if (root.bar) {
            root.bar.hideTooltip(tooltipAnchor);
        }
    }

    function updateSetting(name, value) {
        const current = root.settings || {};
        const entry = { id: root.moduleName };

        for (const key in current) {
            if (key !== "id") {
                entry[key] = current[key];
            }
        }

        // Always persist the complete module state. `root.settings` can still
        // hold the pre-injection value while the shell writes shell.json, so
        // relying on it alone would drop keys that were just changed.
        entry.showCpu = root.showCpu;
        entry.showMemory = root.showMemory;
        entry.showSwap = root.showSwap;
        entry.showGpu = root.showGpu;
        entry.showBattery = root.showBattery;
        entry.showNet = root.showNet;
        entry.showTemp = root.showTemp;
        entry.showLoad = root.showLoad;
        entry.showDisk = root.showDisk;
        entry.showColors = root.showColors;
        entry[name] = value;

        root.settings = entry;

        if (root.bar && root.bar.shell
                && typeof root.bar.shell.updateEntryInline === "function") {
            root.bar.shell.updateEntryInline(root.moduleName, entry);
        }
    }

    function updateGpuFromSysfs() {
        gpuBusyFile.path = root.gpuPath;
        gpuBusyFile.reload();

        const value = Number(gpuBusyFile.text().trim());
        root.gpu = Number.isNaN(value) ? null : value;
    }

    function updateGpuFromCommand() {
        gpuProcess.command = ["bash", "-c", root.gpuCommand];
        gpuProcess.running = true;
    }

    readonly property bool opened: settingsLoader.item !== null && settingsLoader.item.visible === true

    function open() {
        if (root.opened) {
            return;
        }

        root.hideSegmentTooltip();
        settingsLoader.active = true;

        const panel = settingsLoader.item;

        if (!panel) {
            Qt.callLater(root.open);
            return;
        }

        panel.hostWidget = root;

        const barWindow = root.QsWindow.window;
        if (barWindow && barWindow.screen) {
            panel.screen = barWindow.screen;
        }

        const window = root.Window.window;
        if (!window) {
            return;
        }

        const pos = root.mapToItem(null, 0, 0);

        panel.panelX = Math.max(
            8,
            Math.min(
                pos.x + (root.width / 2) - (panel.panelWidth / 2),
                window.width - panel.panelWidth - 8
            )
        );

        panel.panelY = window.height - panel.barVisibleOffset;

        if (root.bar && typeof root.bar.requestPopout === "function") {
            root.bar.requestPopout(root);
        }

        panel.visible = true;
    }

    function close() {
        const panel = settingsLoader.item;

        if (!panel || !panel.visible) {
            return;
        }

        panel.visible = false;

        if (root.bar && typeof root.bar.releasePopout === "function") {
            root.bar.releasePopout(root);
        }
    }

    function closeForPopoutSwitch() {
        root.close();
    }

    function togglePanel() {
        if (root.opened) {
            root.close();
        } else {
            root.open();
        }
    }

    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    FileView {
        id: gpuBusyFile
    }

    Process {
        id: gpuDetector

        command: ["bash", root.detectScriptPath]

        stdout: SplitParser {
            onRead: data => {
                try {
                    const detected = JSON.parse(data);

                    root.gpuKind = detected.kind;
                    root.gpuPath = detected.path;
                    root.gpuCommand = detected.command;
                } catch (error) {
                    console.warn("yassm: GPU detection failed:", data, error);
                }
            }
        }
    }

    Process {
        id: gpuProcess

        stdout: SplitParser {
            onRead: data => {
                const value = Number(data.trim());
                root.gpu = Number.isNaN(value) ? null : value;
            }
        }
    }

    Timer {
        interval: root.gpuIntervalMs
        running: root.gpuKind !== "none"
        repeat: true
        triggeredOnStart: true

        onTriggered: {
            if (root.gpuKind === "sysfs") {
                root.updateGpuFromSysfs();
            } else if (root.gpuKind === "nvidia") {
                root.updateGpuFromCommand();
            }
        }
    }

    WidgetButton {
        id: button

        anchors.fill: parent
        bar: root.bar
        text: root.displayText
        labelVisible: false
        tooltipText: ""

        onPressed: function(buttonCode) {
            root.togglePanel();
        }

        TextMetrics {
            id: separatorMetrics

            font.family: button.fontFamily
            font.pixelSize: button.fontSize
            text: "  "
        }

        Row {
            id: labelRow

            anchors.centerIn: parent
            spacing: separatorMetrics.advanceWidth

            Repeater {
                model: root.segmentOrder

                Row {
                    required property string modelData

                    readonly property string metricKey: modelData

                    visible: root.segmentVisible(metricKey)

                    Text {
                        text: root.segmentIcon(metricKey)
                        color: root.segmentIconColor(metricKey)
                        font.family: button.fontFamily
                        font.pixelSize: button.fontSize
                        renderType: Text.NativeRendering
                    }

                    Text {
                        text: " " + root.segmentValue(metricKey)
                        color: root.segmentColor(metricKey)
                        font.family: button.fontFamily
                        font.pixelSize: button.fontSize
                        renderType: Text.NativeRendering
                    }

                    Text {
                        visible: root.segmentSecondaryIcon(metricKey) !== ""
                        text: root.segmentSecondaryIcon(metricKey)
                        color: button.foreground
                        font.family: button.fontFamily
                        font.pixelSize: button.fontSize
                        renderType: Text.NativeRendering
                    }

                    Text {
                        visible: root.segmentSecondaryValue(metricKey) !== ""
                        text: root.segmentSecondaryValue(metricKey)
                        color: root.segmentSecondaryColor(metricKey)
                        font.family: button.fontFamily
                        font.pixelSize: button.fontSize
                        renderType: Text.NativeRendering
                    }
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: root.segmentCache.length === 0
            text: "No module enabled"
            color: button.foreground
            font.family: button.fontFamily
            font.pixelSize: button.fontSize
            renderType: Text.NativeRendering
        }

        // HoverHandler.point does not update on every cursor move on this
        // Quickshell version. A passive MouseArea does, and NoButton keeps
        // clicks flowing to WidgetButton.
        MouseArea {
            id: tooltipTracker

            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            cursorShape: Qt.PointingHandCursor

            onEntered: Qt.callLater(root.refreshTooltip)
            onMouseXChanged: root.updateTooltip()
            onExited: root.hideSegmentTooltip()
        }

        Item {
            id: tooltipAnchor

            width: 1
            height: button.height
            visible: true
            property bool tooltipHovered: false
        }
    }

    LazyLoader {
        id: settingsLoader

        active: false
        source: Qt.resolvedUrl("SettingsPanel.qml").toString()
    }

    IpcHandler {
        target: root.moduleName

        function open(): void { root.open() }
        function close(): void { root.close() }
        function toggle(): void { root.togglePanel() }
        function show(): void { root.open() }
        function hide(): void { root.close() }
    }

    Component.onCompleted: gpuDetector.running = true
}
