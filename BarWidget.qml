pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "lib" as Yassm

BarWidget {
    id: root

    moduleName: "io.github.jotenakis2.yassm"

    readonly property string detectScriptPath: Qt.resolvedUrl("detect-gpu.sh").toString().replace("file://", "")

    readonly property int gpuIntervalMs: 10000

    property var gpu: null

    property string hoveredSegment: ""

    readonly property string sectionMark: "\u0001"
    readonly property string centeredMark: "\u0002"
    readonly property string boldMark: "\u0003"

    readonly property var tooltipContent: {
        if (!root.hoveredSegment) {
            return { title: "", lines: [] };
        }

        const text = root.moduleTooltip(root.hoveredSegment);
        const index = text.indexOf("\n");
        const title = (index < 0 ? text : text.slice(0, index)).replace(/\u00A0+$/, "");
        const body = index < 0 ? "" : text.slice(index + 1);
        const lines = [];

        if (body !== "") {
            const raw = body.split("\n");

            for (let i = 0; i < raw.length; i++) {
                const line = raw[i];
                const heading = line.startsWith(root.sectionMark)
                    || line.startsWith(root.centeredMark);
                const bold = !heading && line.startsWith(root.boldMark);

                lines.push({
                    text: heading || bold ? line.slice(1).replace(/\u00A0+$/, "") : line,
                    heading: heading,
                    bold: bold
                });
            }
        }

        return { title: title, lines: lines };
    }

    property var processCpu: []
    property var processMemory: []

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
    property bool showBoxes: setting("showBoxes", true)

    readonly property int moduleSpacing: {
        const value = Math.round(Number(setting("spacing", 2)));
        return Number.isFinite(value) ? Math.max(0, Math.min(5, value)) : 2;
    }

    readonly property int iconGap: {
        const value = Math.round(Number(setting("iconGap", 1)));
        return Number.isFinite(value) ? Math.max(0, Math.min(3, value)) : 1;
    }

    readonly property int refreshInterval: {
        const value = Math.round(Number(setting("refreshInterval", 1)));
        return Number.isFinite(value) ? Math.max(1, Math.min(5, value)) : 1;
    }

    readonly property int processInterval: {
        const value = Math.round(Number(setting("processInterval", 5)));
        return Number.isFinite(value) ? Math.max(2, Math.min(10, value)) : 5;
    }

    // Two pixels is the floor: at zero spaces the glyphs can touch or overlap.
    readonly property real moduleGap: Math.max(2, separatorMetrics.advanceWidth)

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
    readonly property string iconLoadLow: String.fromCodePoint(0xF0F86)
    readonly property string iconLoadMedium: String.fromCodePoint(0xF0F85)
    readonly property string iconLoadHigh: String.fromCodePoint(0xF04C5)
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
            segments.push(makeSegment(
                "load",
                loadIcon(metrics.loadPercent),
                Math.round(metrics.loadPercent),
                "%",
                "load"
            ));
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
                key: "netDown",
                icon: iconNetDown,
                valueText: downText,
                text: iconNetDown + " " + downText,
                value: Math.round(down),
                kind: "net"
            });

            segments.push({
                key: "netUp",
                icon: iconNetUp,
                valueText: upText,
                text: iconNetUp + " " + upText,
                value: Math.round(up),
                kind: "net"
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

        const gap = " ".repeat(root.moduleSpacing);

        return segments.map(function(segment) {
            return segment.text;
        }).join(gap);
    }

    readonly property var segmentOrder: ["cpu", "load", "gpu", "memory", "swap", "disk", "netDown", "netUp", "temp", "battery"]

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
        // icon uses the theme blue. The value stays in the normal bar color.
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

    function loadIcon(percent) {
        const value = Math.round(Number(percent));

        if (!Number.isFinite(value) || value <= 50) {
            return iconLoadLow;
        }

        if (value <= 90) {
            return iconLoadMedium;
        }

        return iconLoadHigh;
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
            return button.foreground;
        }

        if (!Number.isFinite(value)) {
            return button.foreground;
        }

        if (value <= 10) {
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

        const value = Math.round(Number(celsius));

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

    function formatKibAsSize(kilobytes) {
        const value = Number(kilobytes);

        if (!Number.isFinite(value) || value <= 0) {
            return "0 B";
        }

        if (value >= 1048576) {
            return (value / 1048576).toFixed(2) + " GiB";
        }

        if (value >= 1024) {
            return (value / 1024).toFixed(2) + " MiB";
        }

        return Math.round(value * 1024) + " B";
    }

    function formatKernelKb(kilobytes) {
        const value = Number(kilobytes);

        if (!Number.isFinite(value) || value <= 0) {
            return "0 B";
        }

        if (value >= 1048576) {
            return (value / 1048576).toFixed(2) + " GiB";
        }

        if (value >= 1024) {
            return Math.round(value / 1024) + " MiB";
        }

        return Math.round(value * 1024) + " B";
    }

    // Compact 4-character rate for the bar (KiB/s): "  0K" … "999K", "1.0M",
    // " 10M", "1.0G". Keeping the value field at 3 characters makes a network
    // half as wide as a percentage module.
    function formatRate(kib) {
        const value = Number(kib);

        if (!Number.isFinite(value) || value <= 0) {
            return "  0K";
        }

        if (value >= 1000 * 1024) {
            const gib = value / 1048576;
            return (gib >= 10 ? gib.toFixed(0) : gib.toFixed(1)).padStart(3, " ") + "G";
        }

        if (value >= 1000) {
            const mib = value / 1024;
            return (mib >= 10 ? mib.toFixed(0) : mib.toFixed(1)).padStart(3, " ") + "M";
        }

        return String(Math.round(value)).padStart(3, " ") + "K";
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

    function aggregateProcesses(content) {
        const byName = {};
        const lines = content.split("\n");

        for (let i = 0; i < lines.length; i++) {
            const parts = lines[i].trim().split(/\s+/);

            if (parts.length < 4) {
                continue;
            }

            const pid = Number(parts[0]);
            const ppid = Number(parts[1]);
            const value = Number(parts[parts.length - 1]);

            if (!Number.isFinite(pid) || !Number.isFinite(ppid)) {
                continue;
            }

            // Kernel threads are children of kthreadd (PID 2); skip them so
            // only userland processes appear in the tooltip.
            if (pid === 2 || ppid === 2) {
                continue;
            }

            if (!Number.isFinite(value) || value <= 0) {
                continue;
            }

            const name = parts.slice(2, -1).join(" ") || "?";

            if (name === "ps") {
                continue;
            }

            byName[name] = (byName[name] || 0) + value;
        }

        const entries = Object.keys(byName).map(function(name) {
            return { name: name, value: byName[name] };
        });

        entries.sort(function(left, right) {
            return right.value - left.value;
        });

        return entries.slice(0, 10);
    }

    function applyProcessCpu(content) {
        const cores = Math.max(1, Number(Yassm.SystemMetrics.nproc) || 1);

        root.processCpu = aggregateProcesses(content).map(function(entry) {
            return { name: entry.name, value: entry.value / cores };
        });
    }

    function applyProcessMemory(content) {
        root.processMemory = aggregateProcesses(content);
    }

    function processTable(entries, memory) {
        let nameWidth = 0;
        let valueWidth = 0;
        const rows = [];

        for (let i = 0; i < entries.length; i++) {
            const name = entries[i].name;
            const value = memory
                ? formatKib(entries[i].value)
                : entries[i].value.toFixed(1) + "%";

            nameWidth = Math.max(nameWidth, name.length);
            valueWidth = Math.max(valueWidth, value.length);
            rows.push({ name: name, value: value });
        }

        return { rows: rows, nameWidth: nameWidth, valueWidth: valueWidth };
    }

    function appendTableRows(lines, table, nameWidth, valueWidth) {
        const nw = nameWidth === undefined ? table.nameWidth : nameWidth;
        const vw = valueWidth === undefined ? table.valueWidth : valueWidth;

        for (let i = 0; i < table.rows.length; i++) {
            const row = table.rows[i];
            lines.push(row.name.padEnd(nw) + "  " + row.value.padStart(vw));
        }
    }

    function appendProcessRows(lines, entries, memory) {
        appendTableRows(lines, processTable(entries, memory));
    }

    function coreEntry(label, value) {
        const percent = Math.max(0, Math.min(100, Math.round(Number(value) || 0)));
        return String(label).padStart(2, " ") + " " + String(percent).padStart(3, " ") + "%";
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
            if (line.startsWith(root.centeredMark)) {
                const body = line.slice(1);
                const visible = body.replace(/[\uD800-\uDBFF][\uDC00-\uDFFF]/g, "_").length;
                const indent = Math.max(0, Math.floor((width - visible) / 2));

                return root.centeredMark + "\u00A0".repeat(indent) + body.padEnd(width - indent, "\u00A0");
            }

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
            const labels = ["Total", "Used", "Available", "Buffer/cache"];
            const values = [
                formatKibAsGib(metrics.memoryTotalKb),
                formatKibAsGib(metrics.memoryUsedKb),
                formatKibAsGib(metrics.memoryAvailableKb),
                formatKibAsGib(metrics.memoryBuffCacheKb)
            ];
            const hasKernel = metrics.kernelTotalKb > 0;
            const table = processTable(root.processMemory, true);
            const kernelValue = hasKernel ? formatKernelKb(metrics.kernelTotalKb) : "";
            let nameWidth = 6;
            let valueWidth = kernelValue.length;

            for (let i = 0; i < labels.length; i++) {
                nameWidth = Math.max(nameWidth, labels[i].length);
                valueWidth = Math.max(valueWidth, values[i].length);
            }

            nameWidth = Math.max(nameWidth, table.nameWidth);
            valueWidth = Math.max(valueWidth, table.valueWidth);

            const lines = [];
            lines.push(root.centeredMark + root.iconMemory + " data");

            for (let i = 0; i < labels.length; i++) {
                lines.push(labels[i].padEnd(nameWidth) + "  " + values[i].padStart(valueWidth));
            }

            if (hasKernel || root.processMemory.length > 0) {
                lines.push("");
                lines.push(root.centeredMark + "proc");
            }

            if (hasKernel) {
                lines.push(root.boldMark + "kernel".padEnd(nameWidth) + "  " + kernelValue.padStart(valueWidth));
            }

            if (root.processMemory.length > 0) {
                appendTableRows(lines, table, nameWidth, valueWidth);
            }

            return tooltipBlock("RAM", lines.join("\n"));
        }

        if (key === "swap") {
            const devices = metrics.swapDevices || [];
            const lines = [];

            if (devices.length > 0) {
                let nameWidth = 0;
                let usedWidth = 0;
                let totalWidth = 0;
                const rows = [];

                for (let i = 0; i < devices.length; i++) {
                    const device = devices[i];
                    const usedText = formatKibAsGib(device.usedKb);
                    const totalText = formatKibAsGib(device.sizeKb);
                    const percent = device.sizeKb > 0
                        ? Math.round(100 * device.usedKb / device.sizeKb)
                        : 0;

                    nameWidth = Math.max(nameWidth, device.name.length);
                    usedWidth = Math.max(usedWidth, usedText.length);
                    totalWidth = Math.max(totalWidth, totalText.length);
                    rows.push({
                        name: device.name,
                        used: usedText,
                        total: totalText,
                        percent: String(percent)
                    });
                }

                for (let i = 0; i < rows.length; i++) {
                    const row = rows[i];

                    lines.push(
                        row.name.padEnd(nameWidth)
                            + "  " + row.used.padStart(usedWidth)
                            + " / " + row.total.padStart(totalWidth)
                            + " (" + row.percent + "%)"
                    );
                }
            } else {
                const percent = metrics.swapTotalKb > 0
                    ? Math.round(100 * metrics.swapUsedKb / metrics.swapTotalKb)
                    : 0;

                lines.push(
                    formatKibAsGib(metrics.swapUsedKb) + " / " + formatKibAsGib(metrics.swapTotalKb)
                        + " (" + percent + "%)"
                );
            }

            const zramLines = [];

            for (let i = 0; i < devices.length; i++) {
                const device = devices[i];

                if (!device.zram) {
                    continue;
                }

                const base = device.name.split("/").pop();
                const stats = metrics.zramStats ? metrics.zramStats[base] : null;

                if (!stats) {
                    continue;
                }

                const ratio = stats.compressedKb > 0
                    ? stats.originalKb / stats.compressedKb
                    : 0;

                zramLines.push(
                    base + ": " + formatKib(stats.compressedKb)
                        + " compressed -> " + formatKib(stats.originalKb)
                        + " original"
                        + (ratio > 0 ? " (" + ratio.toFixed(2) + ":1)" : "")
                        + ", " + formatKib(stats.memKb) + " RAM"
                );
            }

            if (zramLines.length > 0) {
                lines.push("");
                lines.push(root.sectionMark + "ZRAM");

                for (let i = 0; i < zramLines.length; i++) {
                    lines.push(zramLines[i]);
                }
            }

            if (metrics.hasZswap) {
                const ratio = metrics.zswapCompressedKb > 0
                    ? metrics.zswapOriginalKb / metrics.zswapCompressedKb
                    : 0;

                lines.push("");
                lines.push(root.sectionMark + "ZSWAP");
                lines.push(
                    formatKib(metrics.zswapCompressedKb)
                        + " compressed -> " + formatKib(metrics.zswapOriginalKb)
                        + " original"
                        + (ratio > 0 ? " (" + ratio.toFixed(2) + ":1)" : "")
                );
            }

            return tooltipBlock("SWAP", lines.join("\n"));
        }

        if (key === "disk") {
            return mountsTooltip();
        }

        if (key === "cpu") {
            const cores = metrics.corePercents || [];
            const lines = [];

            if (cores.length > 0) {
                lines.push(root.centeredMark + root.iconCpu + " cores");

                // Two columns fit up to 20 cores; beyond that, add columns so
                // the tooltip never grows past 10 rows.
                const columns = Math.max(2, Math.ceil(cores.length / 10));
                const rows = Math.ceil(cores.length / columns);

                for (let row = 0; row < rows; row++) {
                    const cells = [];

                    for (let column = 0; column < columns; column++) {
                        const index = column * rows + row;

                        if (index < cores.length) {
                            cells.push(coreEntry(String(index + 1), cores[index]));
                        }
                    }

                    lines.push(cells.join("     "));
                }
            }

            const table = processTable(root.processCpu, false);
            const kernelValue = metrics.kernelPercent.toFixed(1) + "%";
            const nameWidth = Math.max(6, table.nameWidth);
            const valueWidth = Math.max(kernelValue.length, table.valueWidth);

            if (lines.length > 0) {
                lines.push("");
            }

            lines.push(root.centeredMark + "proc");
            lines.push(root.boldMark + "kernel".padEnd(nameWidth) + "  " + kernelValue.padStart(valueWidth));

            if (root.processCpu.length > 0) {
                appendTableRows(lines, table, nameWidth, valueWidth);
            }

            return tooltipBlock("CPU", lines.join("\n"));
        }

        if (key === "gpu") {
            return tooltipBlock("GPU", gpu === null ? "Unavailable" : Math.round(gpu) + "%");
        }

        if (key === "net" || key === "netDown" || key === "netUp") {
            const metrics = Yassm.SystemMetrics;

            if (!metrics.hasNetwork) {
                return tooltipBlock("NET", "Unavailable");
            }

            const lines = [
                metrics.networkInterface,
                "↓ " + formatRateLong(metrics.networkRxKib)
                    + "  (session " + formatKibAsSize(metrics.networkRxSessionKb) + ")",
                "↑ " + formatRateLong(metrics.networkTxKib)
                    + "  (session " + formatKibAsSize(metrics.networkTxSessionKb) + ")"
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

    function refreshProcesses() {
        if (root.hoveredSegment === "cpu") {
            if (!cpuTopProcess.running) {
                cpuTopProcess.running = true;
            }
        } else if (root.hoveredSegment === "memory") {
            if (!memoryTopProcess.running) {
                memoryTopProcess.running = true;
            }
        }
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

        if (hit.key === "cpu") {
            root.processCpu = [];
        } else if (hit.key === "memory") {
            root.processMemory = [];
        }

        root.refreshProcesses();

        tooltipAnchor.x = hit.center - tooltipAnchor.width / 2;
    }

    function refreshTooltip() {
        root.hoveredSegment = "";
        root.updateTooltip();
    }

    function hideSegmentTooltip() {
        root.hoveredSegment = "";
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
        entry.showBoxes = root.showBoxes;
        entry.iconGap = root.iconGap;
        entry.spacing = root.moduleSpacing;
        entry.refreshInterval = root.refreshInterval;
        entry.processInterval = root.processInterval;
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

    implicitWidth: Math.max(Math.ceil(labelRow.width), Math.ceil(emptyLabel.implicitWidth))
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

    Process {
        id: cpuTopProcess

        command: ["ps", "-eo", "pid=,ppid=,comm=,%cpu=", "--sort=-%cpu"]

        stdout: StdioCollector {
            id: cpuTopOutput
            waitForEnd: true

            onStreamFinished: {
                root.applyProcessCpu(cpuTopOutput.text);
            }
        }
    }

    Process {
        id: memoryTopProcess

        command: ["ps", "-eo", "pid=,ppid=,comm=,rss=", "--sort=-rss"]

        stdout: StdioCollector {
            id: memoryTopOutput
            waitForEnd: true

            onStreamFinished: {
                root.applyProcessMemory(memoryTopOutput.text);
            }
        }
    }

    // Keep the process list live while the CPU or RAM tooltip is open.
    Timer {
        interval: root.processInterval * 1000
        repeat: true
        running: root.hoveredSegment === "cpu" || root.hoveredSegment === "memory"

        onTriggered: root.refreshProcesses()
    }

    // All bar instances share one sampler; the value is identical for each.
    Binding {
        target: Yassm.SystemMetrics
        property: "fastIntervalMs"
        value: root.refreshInterval * 1000
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
            text: " ".repeat(root.moduleSpacing)
        }

        TextMetrics {
            id: cellMetrics

            font.family: button.fontFamily
            font.pixelSize: button.fontSize
            text: "0"
        }

        Row {
            id: labelRow

            anchors.centerIn: parent
            spacing: root.moduleGap

            Repeater {
                model: root.segmentOrder

                Rectangle {
                    id: segmentBox

                    required property string modelData

                    readonly property string metricKey: modelData
                    readonly property int paddingX: root.showBoxes ? Style.space(4) : 0
                    readonly property int paddingY: root.showBoxes ? Style.space(2) : 0

                    visible: root.segmentVisible(metricKey)
                    implicitWidth: segmentContent.implicitWidth + paddingX * 2
                    implicitHeight: segmentContent.implicitHeight + paddingY * 2
                    radius: root.showBoxes ? Style.space(4) : 0
                    color: root.showBoxes
                        ? Qt.rgba(button.foreground.r, button.foreground.g, button.foreground.b, 0.03)
                        : "transparent"
                    border.width: root.showBoxes ? Math.max(1, Style.normalBorderWidth) : 0
                    border.color: root.showBoxes
                        ? Qt.rgba(button.foreground.r, button.foreground.g, button.foreground.b, 0.20)
                        : "transparent"

                    Row {
                        id: segmentContent

                        anchors.centerIn: parent
                        spacing: 0

                        Text {
                            text: root.segmentIcon(metricKey)
                            color: root.segmentIconColor(metricKey)
                            font.family: button.fontFamily
                            font.pixelSize: button.fontSize
                            renderType: Text.NativeRendering
                        }

                        Item {
                            width: Math.max(2, root.iconGap * cellMetrics.advanceWidth)
                            height: 1
                        }

                        Text {
                            text: root.segmentValue(metricKey)
                            color: root.segmentColor(metricKey)
                            font.family: button.fontFamily
                            font.pixelSize: button.fontSize
                            renderType: Text.NativeRendering
                        }
                    }
                }
            }
        }

        Text {
            id: emptyLabel

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
        }
    }

    PopupWindow {
        id: widgetTooltip

        visible: root.hoveredSegment !== ""
        color: "transparent"
        implicitWidth: tooltipBubble.implicitWidth
        implicitHeight: tooltipBubble.implicitHeight

        anchor {
            id: widgetTooltipAnchor

            window: root.QsWindow.window
            adjustment: PopupAdjustment.Slide
            edges: Edges.Top | Edges.Left
            gravity: Edges.Bottom | Edges.Right
            rect.width: 1
            rect.height: 1

            onAnchoring: {
                const target = tooltipAnchor;
                const barWindow = root.QsWindow.window;

                if (!barWindow) {
                    return;
                }

                const position = root.bar ? root.bar.position : "top";
                const popupWidth = widgetTooltip.implicitWidth;
                const popupHeight = widgetTooltip.implicitHeight;
                let localX = target.width / 2 - popupWidth / 2;
                let localY = target.height + 6;

                if (position === "bottom") {
                    localY = -popupHeight - 6;
                } else if (position === "left") {
                    localX = target.width + 6;
                    localY = target.height / 2 - popupHeight / 2;
                } else if (position === "right") {
                    localX = -popupWidth - 6;
                    localY = target.height / 2 - popupHeight / 2;
                }

                const point = barWindow.contentItem.mapFromItem(target, localX, localY);
                widgetTooltipAnchor.rect.x = Math.round(point.x);
                widgetTooltipAnchor.rect.y = Math.round(point.y);
            }
        }

        BorderSurface {
            id: tooltipBubble

            implicitWidth: tooltipColumn.implicitWidth + 20
            implicitHeight: tooltipColumn.implicitHeight + 14
            color: ShellColor.tooltip.background
            borderSpec: Border.surfaceSpec("tooltip", "border", ShellColor.tooltip.border, 1)
            radius: Style.cornerRadius

            Column {
                id: tooltipColumn

                anchors.centerIn: parent
                spacing: 0

                Text {
                    id: tooltipTitle

                    textFormat: Text.PlainText
                    text: root.tooltipContent.title
                    color: ShellColor.tooltip.text
                    font.family: button.fontFamily
                    font.pixelSize: Style.font.body
                    font.weight: Font.Bold
                    renderType: Text.NativeRendering
                    bottomPadding: Style.space(2)
                }

                Repeater {
                    model: root.tooltipContent.lines

                    Text {
                        required property var modelData

                        textFormat: Text.PlainText
                        text: modelData.text
                        color: modelData.heading ? ShellColor.tooltip.text : ShellColor.muted
                        font.family: button.fontFamily
                        font.pixelSize: Style.font.body
                        font.weight: modelData.heading || modelData.bold ? Font.Bold : Font.Normal
                        renderType: Text.NativeRendering
                    }
                }
            }
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
