pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "lib" as Yassm

BarWidget {
    id: root

    moduleName: "io.github.jotenakis2.yassm"

    readonly property string detectScriptPath: decodeURIComponent(Qt.resolvedUrl("detect-gpu.sh").toString().replace("file://", ""))
    readonly property string procSnapshotPath: decodeURIComponent(Qt.resolvedUrl("proc-snapshot.sh").toString().replace("file://", ""))
    readonly property string diskIoScriptPath: decodeURIComponent(Qt.resolvedUrl("disk-io.sh").toString().replace("file://", ""))
    readonly property string alertsViewScriptPath: decodeURIComponent(Qt.resolvedUrl("alerts-view.sh").toString().replace("file://", ""))

    // Linux USER_HZ is 100 on the supported architectures.
    readonly property int clkTck: 100

    property var gpu: null

    property var cpuSnapshot: null
    property real cpuSnapshotTime: 0

    property string hoveredSegment: ""

    // The widget is built as a horizontal row of modules. A vertical bar only
    // offers a barSize-wide slot, so hide gracefully instead of overflowing.
    readonly property bool barVertical: root.bar ? root.bar.vertical === true : false
    visible: !root.barVertical

    readonly property string sectionMark: "\u0001"
    readonly property string centeredMark: "\u0002"
    readonly property string boldMark: "\u0003"

    readonly property var tooltipContent: {
        if (!root.hoveredSegment) {
            return {
                title: "",
                lines: []
            };
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
                const heading = line.startsWith(root.sectionMark) || line.startsWith(root.centeredMark);
                const bold = !heading && line.startsWith(root.boldMark);

                lines.push({
                    text: heading || bold ? line.slice(1).replace(/\u00A0+$/, "") : line,
                    heading: heading,
                    bold: bold
                });
            }
        }

        return {
            title: title,
            lines: lines
        };
    }

    onTooltipContentChanged: root.syncTooltipModel()

    ListModel {
        id: tooltipLineModel
    }

    property var processCpu: []
    property var processMemory: []
    property var diskProcesses: []
    property var diskIoSnapshot: null

    property bool hasBtop: false

    property string gpuKind: "none"
    property string gpuPath: ""
    property string gpuCommand: ""

    property bool showCpu: setting("showCpu", true)
    property bool showMemory: setting("showMemory", true)
    property bool showSwap: setting("showSwap", true)
    property bool showGpu: setting("showGpu", true)
    property bool showBattery: setting("showBattery", true)
    property bool showAlerts: setting("showAlerts", true)
    property bool showUptime: setting("showUptime", true)
    property bool showExtended: setting("extendedTooltips", true)
    property bool showNet: setting("showNet", true)
    property bool showTemp: setting("showTemp", true)
    property bool showLoad: setting("showLoad", true)
    property bool showDisk: setting("showDisk", true)
    property bool showColors: setting("showColors", true)
    property bool showBoxes: setting("showBoxes", true)

    // Module frame style. An absent boxBorder means "use the theme's border
    // width"; boxRadius defaults to 4 px. Both are scaled like the rest of
    // the shell geometry.
    readonly property int boxBorder: {
        const value = Math.round(Number(setting("boxBorder", -1)));

        if (!Number.isFinite(value) || value < 1) {
            return Math.max(1, Math.min(4, Style.normalBorderWidth));
        }

        return Math.max(1, Math.min(4, value));
    }
    readonly property int boxRadius: {
        const value = Math.round(Number(setting("boxRadius", 4)));

        return Number.isFinite(value) ? Math.max(0, Math.min(12, value)) : 4;
    }

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

    readonly property int slowInterval: {
        const value = Math.round(Number(setting("slowInterval", 10)));
        return Number.isFinite(value) ? Math.max(5, Math.min(30, value)) : 10;
    }

    // Temperature thresholds are user-tunable: machines differ by tens of
    // degrees. Values are normalised so an inconsistent shell.json cannot
    // invert the order.
    readonly property int temperatureWarm: Math.min(120, Math.max(0, Math.round(Number(setting("tempWarm", 40)) || 40)))
    readonly property int temperatureHot: Math.max(temperatureWarm + 1, Math.min(130, Math.round(Number(setting("tempHot", 50)) || 50)))
    readonly property int temperatureCritical: Math.max(temperatureHot + 1, Math.min(140, Math.round(Number(setting("tempCritical", 60)) || 60)))

    // Colour thresholds for the other families. Ascending families need
    // green < orange < red; the battery is inverted (normal high, red low).
    // Everything is applied to the rounded value shown in the bar.
    function thresholdValue(key, fallback, minimum, maximum) {
        const raw = Number(setting(key, fallback));
        const value = Number.isFinite(raw) ? Math.round(raw) : fallback;

        return Math.max(minimum, Math.min(maximum, value));
    }

    readonly property int percentGreen: thresholdValue("percentGreen", 10, 1, 98)
    readonly property int percentOrange: thresholdValue("percentOrange", 33, percentGreen + 1, 99)
    readonly property int percentRed: thresholdValue("percentRed", 66, percentOrange + 1, 100)
    readonly property int diskGreen: thresholdValue("diskGreen", 20, 1, 98)
    readonly property int diskOrange: thresholdValue("diskOrange", 33, diskGreen + 1, 99)
    readonly property int diskRed: thresholdValue("diskRed", 90, diskOrange + 1, 100)
    readonly property int loadGreen: thresholdValue("loadGreen", 10, 0, 198)
    readonly property int loadOrange: thresholdValue("loadOrange", 50, loadGreen + 1, 199)
    readonly property int loadRed: thresholdValue("loadRed", 90, loadOrange + 1, 200)
    readonly property int netGreen: thresholdValue("netGreen", 10, 1, 9998)
    readonly property int netOrange: thresholdValue("netOrange", 500, netGreen + 1, 9999)
    readonly property int netRed: thresholdValue("netRed", 1000, netOrange + 1, 10000)
    readonly property int batteryGreen: thresholdValue("batteryGreen", 50, 2, 100)
    readonly property int batteryOrange: thresholdValue("batteryOrange", 20, 1, batteryGreen - 1)
    readonly property int batteryRed: thresholdValue("batteryRed", 10, 0, batteryOrange - 1)

    readonly property int maxProcesses: {
        const value = Math.round(Number(setting("maxProcesses", 10)));
        return Number.isFinite(value) ? Math.max(1, Math.min(20, value)) : 10;
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
    readonly property string iconNetOff: String.fromCodePoint(0xF0C9B)
    readonly property string iconWifi: String.fromCodePoint(0xF05A9)
    readonly property string iconEthernet: String.fromCodePoint(0xF0200)
    readonly property string iconTemp: String.fromCodePoint(0xF050F)
    readonly property string iconFan: String.fromCodePoint(0xF0210)
    readonly property string iconProc: String.fromCodePoint(0xF018D)
    readonly property string iconCompress: String.fromCodePoint(0xF066)
    readonly property string iconServer: String.fromCodePoint(0xF233)
    readonly property string iconUser: String.fromCodePoint(0xF007)
    readonly property string iconGhost: String.fromCodePoint(0xEEFE)
    readonly property string iconLoadLow: String.fromCodePoint(0xF0F86)
    readonly property string iconLoadMedium: String.fromCodePoint(0xF0F85)
    readonly property string iconLoadHigh: String.fromCodePoint(0xF04C5)
    readonly property string iconDisk: String.fromCodePoint(0xF02CA)
    readonly property string iconAlert: String.fromCodePoint(0xF071)
    readonly property string iconUptime: String.fromCodePoint(0xF017)

    // Battery with the bolt inside the outline: one compact glyph, unlike the
    // per-level charging icons whose bolt sticks out past the cell.
    readonly property string iconBatteryCharging: String.fromCodePoint(0xF0084)

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

    function batteryIcon(percent, status, plugged) {
        if (status === "Charging") {
            return iconBatteryCharging;
        }

        // On mains but not charging (full or charge threshold reached), a
        // single plug glyph says it, macOS style. Appending a plug to the
        // battery icon made the segment one cell wider and shifted the bar.
        return plugged ? iconBatteryPlug : batteryLevelIcon(percent);
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

        if (showUptime) {
            const uptimeText = formatUptime(metrics.uptimeSeconds);

            segments.push({
                key: "uptime",
                icon: iconUptime,
                valueText: uptimeText,
                text: iconUptime + " " + uptimeText,
                value: metrics.uptimeSeconds,
                kind: "uptime"
            });
        }

        if (showCpu) {
            segments.push(makeSegment("cpu", iconCpu, Math.round(metrics.cpuPercent), "%", "percent"));
        }

        if (showLoad) {
            segments.push(makeSegment("load", loadIcon(metrics.loadPercent), Math.round(metrics.loadPercent), "%", "load"));
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
            segments.push(makeSegment("disk", iconDisk, Math.round(metrics.diskPercent), "%", "disk"));
        }

        if (showNet) {
            if (metrics.hasNetwork) {
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
            } else {
                segments.push({
                    key: "netOffline",
                    icon: iconNetOff,
                    valueText: " --",
                    text: iconNetOff + " --",
                    value: null,
                    kind: "netOffline"
                });
            }
        }

        if (showBattery && metrics.hasBattery) {
            segments.push(makeSegment("battery", root.batteryIcon(metrics.batteryPercent, metrics.batteryStatus, metrics.batteryPlugged), Math.round(metrics.batteryPercent), "%", "battery"));
        }

        if (showAlerts && metrics.hasAlerts) {
            segments.push({
                key: "alerts",
                icon: iconAlert,
                valueText: "",
                text: iconAlert,
                value: null,
                kind: "alerts"
            });
        }

        if (showTemp) {
            segments.push(makeSegment("temp", iconTemp, metrics.hasTemperature ? Math.round(metrics.temperatureC) : null, "°C", "temp"));
        }

        return segments;
    }

    // User-visible module order (Settings, drag & drop). "net" expands to the
    // three network segment keys; unknown or missing keys are repaired here so
    // an old config, a removed module or a future addition never breaks the bar.
    readonly property var defaultModuleOrder: ["uptime", "cpu", "load", "gpu", "memory", "swap", "disk", "net", "temp", "battery", "alerts"]
    readonly property var moduleOrder: {
        // Values loaded from shell.json arrive as a QVariantList, for which
        // Array.isArray() is false even though it behaves like an array;
        // normalise it first, otherwise the saved order is ignored on every
        // shell restart and the bar falls back to the default order.
        const raw = setting("moduleOrder", []);
        const saved = raw && typeof raw.length === "number" ? Array.prototype.slice.call(raw) : [];
        const defaults = root.defaultModuleOrder;
        const order = [];
        const seen = {};

        for (let i = 0; i < saved.length; i++) {
            const key = saved[i];

            if (typeof key === "string" && defaults.indexOf(key) >= 0 && !seen[key]) {
                seen[key] = true;
                order.push(key);
            }
        }

        for (let i = 0; i < defaults.length; i++) {
            if (!seen[defaults[i]]) {
                order.push(defaults[i]);
            }
        }

        return order;
    }
    readonly property var segmentOrder: {
        const keys = [];

        for (let i = 0; i < root.moduleOrder.length; i++) {
            const key = root.moduleOrder[i];

            if (key === "net") {
                keys.push("netDown", "netUp", "netOffline");
            } else {
                keys.push(key);
            }
        }

        return keys;
    }

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

        const metrics = Yassm.SystemMetrics;

        if (key === "alerts") {
            return metrics.hasSystemFailure || metrics.diskAlert || metrics.memoryAlert ? Yassm.ThemePalette.red : Yassm.ThemePalette.orange;
        }

        if (key === "netOffline") {
            return Yassm.ThemePalette.red;
        }

        if (key !== "battery") {
            return button.foreground;
        }

        // On mains power, charging or held at a charge threshold, the battery
        // icon uses the theme green. The value stays in the normal bar color.
        if (metrics.batteryPlugged) {
            return Yassm.ThemePalette.green;
        }

        return button.foreground;
    }

    function segmentColor(key) {
        if (!root.showColors) {
            return button.foreground;
        }
        const segment = segmentMap[key];

        if (!segment) {
            return button.foreground;
        }

        if (segment.kind === "netOffline") {
            return Yassm.ThemePalette.red;
        }

        if (segment.kind === "uptime") {
            return button.foreground;
        }

        if (segment.value === null || !Number.isFinite(segment.value)) {
            return button.foreground;
        }

        if (segment.kind === "battery") {
            return batteryColor(segment.value);
        }

        if (segment.kind === "disk") {
            return diskColor(segment.value);
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
        if (!Number.isFinite(value) || value < root.percentGreen) {
            return button.foreground;
        }

        if (value < root.percentOrange) {
            return Yassm.ThemePalette.green;
        }

        if (value < root.percentRed) {
            return Yassm.ThemePalette.orange;
        }

        return Yassm.ThemePalette.red;
    }

    function diskColor(value) {
        // Disks fill slowly: the green boundary is higher than for RAM/CPU.
        if (!Number.isFinite(value) || value < root.diskGreen) {
            return button.foreground;
        }

        if (value < root.diskOrange) {
            return Yassm.ThemePalette.green;
        }

        if (value < root.diskRed) {
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
        if (!Number.isFinite(value) || value < root.loadGreen) {
            return button.foreground;
        }

        if (value < root.loadOrange) {
            return Yassm.ThemePalette.green;
        }

        if (value < root.loadRed) {
            return Yassm.ThemePalette.orange;
        }

        return Yassm.ThemePalette.red;
    }

    function networkColor(value) {
        const kib = Number(value);

        if (!Number.isFinite(kib) || kib < root.netGreen) {
            return button.foreground;
        }

        if (kib < root.netOrange) {
            return Yassm.ThemePalette.green;
        }

        if (kib < root.netRed) {
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

        if (value <= root.batteryRed) {
            return Yassm.ThemePalette.red;
        }

        if (value < root.batteryOrange) {
            return Yassm.ThemePalette.orange;
        }

        if (value < root.batteryGreen) {
            return Yassm.ThemePalette.green;
        }

        return button.foreground;
    }

    function temperatureColor(value) {
        if (!Number.isFinite(value) || value < root.temperatureWarm) {
            return button.foreground;
        }

        if (value < root.temperatureHot) {
            return Yassm.ThemePalette.green;
        }

        if (value < root.temperatureCritical) {
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

    // Compact 4-character rate for the bar (KiB/s): "  0K" … "999K", "1.0M",
    // " 10M", "1.0G". Keeping the value field at 3 characters makes a network
    // half as wide as a percentage module.
    function formatRate(kib) {
        const value = Number(kib);

        if (!Number.isFinite(value) || value <= 0) {
            return "  0K";
        }

        // Thresholds use the rounded width so the value never spills over to
        // "1000K" or "1000M" and widens the bar for a single tick. The switch
        // to an integer happens as soon as the one-decimal form would reach
        // 10.0, otherwise "10.0M" is one character wider than "9.9M".
        if (value >= 999.5 * 1024) {
            const gib = value / 1048576;
            return (gib >= 9.95 ? String(Math.round(gib)) : gib.toFixed(1)).padStart(3, " ") + "G";
        }

        if (value >= 999.5) {
            const mib = value / 1024;
            return (mib >= 9.95 ? String(Math.round(mib)) : mib.toFixed(1)).padStart(3, " ") + "M";
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
        return formatKibAsGib(Number(bytes) / 1024);
    }

    function aggregateProcesses(content, limit) {
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

        const entries = Object.keys(byName).map(function (name) {
            return {
                name: name,
                value: byName[name]
            };
        });

        entries.sort(function (left, right) {
            return right.value - left.value;
        });

        return entries.slice(0, limit || 10);
    }

    function applyProcessMemory(content) {
        root.processMemory = aggregateProcesses(content, root.maxProcesses);
    }

    function startDiskIo() {
        if (!diskIoProcess.running) {
            diskIoProcess.running = true;
        }
    }

    function applyDiskIo(content) {
        const now = Date.now();
        const previous = root.diskIoSnapshot;
        const current = {};
        const byName = {};
        const lines = String(content || "").split("\n");

        for (let i = 0; i < lines.length; i++) {
            if (lines[i] === "") {
                continue;
            }

            const parts = lines[i].split("\t");

            if (parts.length < 4) {
                continue;
            }

            const key = parts[0];
            const name = parts[1];
            const read = Number(parts[2]);
            const write = Number(parts[3]);

            if (!Number.isFinite(read) || !Number.isFinite(write)) {
                continue;
            }

            current[key] = {
                read: read,
                write: write
            };

            if (!previous || !previous.entries[key]) {
                continue;
            }

            const elapsed = Math.max(0.5, (now - previous.time) / 1000);
            const readDelta = Math.max(0, read - previous.entries[key].read);
            const writeDelta = Math.max(0, write - previous.entries[key].write);

            if (readDelta + writeDelta <= 0) {
                continue;
            }

            const entry = byName[name] || {
                name: name,
                read: 0,
                write: 0
            };

            entry.read += readDelta / elapsed;
            entry.write += writeDelta / elapsed;
            byName[name] = entry;
        }

        root.diskIoSnapshot = {
            time: now,
            entries: current
        };

        if (!previous) {
            // First sample is only a baseline; take a second one quickly so
            // the section does not stay empty for a whole refresh interval.
            diskWarmupTimer.restart();
            return;
        }

        const entries = Object.keys(byName).map(function (name) {
            return byName[name];
        });

        entries.sort(function (left, right) {
            return (right.read + right.write) - (left.read + left.write);
        });

        root.diskProcesses = entries.slice(0, root.maxProcesses);
    }

    function startCpuSnapshot() {
        if (!procSnapshotProcess.running) {
            procSnapshotProcess.running = true;
        }
    }

    function applyProcSnapshot(content) {
        if (root.hoveredSegment !== "cpu") {
            root.cpuSnapshot = null;
            return;
        }

        const now = Date.now();
        const current = {};
        const lines = content.split("\n");

        for (let i = 0; i < lines.length; i++) {
            const line = lines[i];

            if (line === "") {
                continue;
            }

            const open = line.indexOf("(");
            const close = line.lastIndexOf(")");

            if (open < 0 || close <= open) {
                continue;
            }

            const pid = Number(line.slice(0, open).trim());
            const comm = line.slice(open + 1, close);
            const fields = line.slice(close + 2).trim().split(/\s+/);

            if (!Number.isFinite(pid) || fields.length < 13) {
                continue;
            }

            const ppid = Number(fields[1]);
            const ticks = Number(fields[11]) + Number(fields[12]);

            if (!Number.isFinite(ppid) || !Number.isFinite(ticks)) {
                continue;
            }

            current[pid] = {
                comm: comm,
                ppid: ppid,
                ticks: ticks
            };
        }

        const previous = root.cpuSnapshot;
        const previousTime = root.cpuSnapshotTime;

        root.cpuSnapshot = current;
        root.cpuSnapshotTime = now;

        if (!previous) {
            // First snapshot is only a baseline; take a second one quickly so
            // the tooltip does not stay empty for a whole refresh interval.
            cpuWarmupTimer.restart();
            return;
        }

        const elapsed = (now - previousTime) / 1000;

        if (!(elapsed > 0)) {
            return;
        }

        const byName = {};
        const cores = Math.max(1, Number(Yassm.SystemMetrics.nproc) || 1);

        for (const key in current) {
            const entry = current[key];

            // Kernel threads are children of kthreadd (PID 2).
            if (Number(key) === 2 || entry.ppid === 2) {
                continue;
            }

            const before = previous[key];
            let percent = 0;

            if (before && entry.ticks > before.ticks) {
                const seconds = (entry.ticks - before.ticks) / root.clkTck;
                percent = 100 * seconds / elapsed / cores;
            }

            // Keep zero-delta processes too: the list is capped by the
            // "Processes shown" setting, so 20 always means 20 userland rows
            // when that many processes exist (idle ones display 0.0%).
            byName[entry.comm] = (byName[entry.comm] || 0) + percent;
        }

        const entries = Object.keys(byName).map(function (name) {
            return {
                name: name,
                value: byName[name]
            };
        });

        entries.sort(function (left, right) {
            if (right.value !== left.value) {
                return right.value - left.value;
            }

            return left.name < right.name ? -1 : (left.name > right.name ? 1 : 0);
        });

        root.processCpu = entries.slice(0, root.maxProcesses);
    }

    function processTable(entries, memory) {
        let nameWidth = 0;
        let valueWidth = 0;
        const rows = [];

        for (let i = 0; i < entries.length; i++) {
            const name = entries[i].name;
            const value = memory ? formatKib(entries[i].value) : entries[i].value.toFixed(1) + "%";

            nameWidth = Math.max(nameWidth, name.length);
            valueWidth = Math.max(valueWidth, value.length);
            rows.push({
                name: name,
                value: value
            });
        }

        return {
            rows: rows,
            nameWidth: nameWidth,
            valueWidth: valueWidth
        };
    }

    function appendTableRows(lines, table, nameWidth, valueWidth) {
        const nw = nameWidth === undefined ? table.nameWidth : nameWidth;
        const vw = valueWidth === undefined ? table.valueWidth : valueWidth;

        for (let i = 0; i < table.rows.length; i++) {
            const row = table.rows[i];
            lines.push(row.name.padEnd(nw) + "  " + row.value.padStart(vw));
        }
    }

    function coreEntry(label, value, labelWidth, frequency, frequencyWidth) {
        const percent = Math.max(0, Math.min(100, Math.round(Number(value) || 0)));
        let entry = String(label).padStart(labelWidth || 2, " ") + " " + String(percent).padStart(3, " ") + "%";

        if (frequencyWidth > 0) {
            const mhz = Number(frequency);
            const text = Number.isFinite(mhz) && mhz > 0 ? String(Math.round(mhz)).padStart(frequencyWidth) : "--".padStart(frequencyWidth);

            entry += " (" + text + "MHz)";
        }

        return entry;
    }

    function batteryStateLabel(status) {
        switch (status) {
        case "Charging":
            return Yassm.I18n.t("battery.charging");
        case "Discharging":
            return Yassm.I18n.t("battery.discharging");
        case "Full":
            return Yassm.I18n.t("battery.full");
        case "Not charging":
            return Yassm.I18n.t("battery.not_charging");
        case "Empty":
            return Yassm.I18n.t("battery.empty");
        case "Pending charge":
            return Yassm.I18n.t("battery.pending_charge");
        case "Pending discharge":
            return Yassm.I18n.t("battery.pending_discharge");
        default:
            return status || Yassm.I18n.t("battery.unknown");
        }
    }

    function batteryPowerArrow() {
        const status = Yassm.SystemMetrics.batteryStatus;

        if (status === "Discharging") {
            return "↓";
        }

        if (status === "Charging") {
            return "↑";
        }

        return "";
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

    function formatUptime(seconds) {
        const totalMinutes = Math.floor(Math.max(0, Number(seconds) || 0) / 60);
        const hours = Math.floor(totalMinutes / 60);
        const minutes = totalMinutes % 60;

        return hours > 0 ? hours + "h" + String(minutes).padStart(2, "0") : minutes + "m";
    }

    function formatUptimeLong(seconds) {
        const totalMinutes = Math.floor(Math.max(0, Number(seconds) || 0) / 60);
        const hours = Math.floor(totalMinutes / 60);
        const minutes = totalMinutes % 60;

        return hours > 0 ? hours + "h " + minutes + "m" : minutes + "m";
    }

    function installAgeDays() {
        const epoch = Yassm.SystemMetrics.installEpoch;

        if (!(epoch > 0)) {
            return -1;
        }

        return Math.max(0, Math.floor((Date.now() / 1000 - epoch) / 86400));
    }

    function formatInstallAge(days) {
        return days + " " + Yassm.I18n.plural("uptime.days", days);
    }

    // Installation age and date belong to the extended data: they are static
    // facts about the machine, not part of the live uptime reading.
    function installRows(bootLabel) {
        const metrics = Yassm.SystemMetrics;
        const ageDays = root.installAgeDays();
        const ageLabel = Yassm.I18n.t("uptime.age");
        const dateLabel = Yassm.I18n.t("uptime.date");
        const width = Math.max(bootLabel.length, ageLabel.length, dateLabel.length);
        const lines = [];

        if (ageDays >= 0) {
            lines.push(ageLabel.padEnd(width) + " : " + root.formatInstallAge(ageDays));
        }

        lines.push(dateLabel.padEnd(width) + " : " + (metrics.installDate !== "" ? metrics.installDate : Yassm.I18n.t("common.unknown")));

        return {
            width: width,
            lines: lines
        };
    }

    function singlePressureRows(ten, sixty, threeHundred) {
        const labels = ["10s", "60s", "300s"];
        const values = [ten, sixty, threeHundred].map(function (value) {
            return Number(value || 0).toFixed(1) + "%";
        });
        // Fixed columns: PSI values never shift when a digit appears.
        const valueWidth = 6;

        return labels.map(function (label, index) {
            return label.padStart(4) + "  " + values[index].padStart(valueWidth);
        });
    }

    function pressureRows(someTen, someSixty, someThreeHundred, fullTen, fullSixty, fullThreeHundred) {
        const labels = ["10s", "60s", "300s"];
        const some = [someTen, someSixty, someThreeHundred].map(function (value) {
            return Number(value || 0).toFixed(1) + "%";
        });
        const full = [fullTen, fullSixty, fullThreeHundred].map(function (value) {
            return Number(value || 0).toFixed(1) + "%";
        });
        const labelWidth = 4;
        // Fixed columns: PSI values never shift when a digit appears.
        const valueWidth = 6;

        const lines = ["".padEnd(labelWidth) + "  " + "some".padStart(valueWidth) + "  " + "full".padStart(valueWidth)];

        for (let i = 0; i < labels.length; i++) {
            lines.push(labels[i].padStart(labelWidth) + "  " + some[i].padStart(valueWidth) + "  " + full[i].padStart(valueWidth));
        }

        return lines;
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
            return tooltipBlock(Yassm.I18n.t("title.disk"), Yassm.I18n.t("common.unavailable"));
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
            rows.push({
                target: target,
                used: used,
                total: total,
                percent: percent
            });
        }

        const lines = [root.centeredMark + root.iconDisk + " " + Yassm.I18n.t("head.usage")];

        for (let i = 0; i < rows.length; i++) {
            lines.push(rows[i].target.padEnd(targetWidth) + "  " + rows[i].used.padStart(usedWidth) + " / " + rows[i].total.padStart(totalWidth) + " " + rows[i].percent.padStart(percentWidth));
        }

        const metrics = Yassm.SystemMetrics;

        if (root.showExtended) {
            lines.push("");
            lines.push(root.centeredMark + root.iconSwap + " " + Yassm.I18n.t("head.io"));
            lines.push("R " + formatRateLong(metrics.diskReadKib) + "  W " + formatRateLong(metrics.diskWriteKib));
            lines.push("");
            lines.push(root.centeredMark + root.iconLoadHigh + " " + Yassm.I18n.t("head.pressure"));

            const pressure = pressureRows(metrics.ioPressure10, metrics.ioPressure60, metrics.ioPressure300, metrics.ioPressureFull10, metrics.ioPressureFull60, metrics.ioPressureFull300);

            for (let i = 0; i < pressure.length; i++) {
                lines.push(pressure[i]);
            }

            lines.push("");
            lines.push(root.centeredMark + root.iconProc + " " + Yassm.I18n.t("head.proc_user"));

            const nameWidth = 15;
            // "999.9 MiB/s" is the widest rate (11 chars); a 10-wide field
            // let 100+ MiB/s values widen the whole tooltip.
            const rateWidth = 11;
            // name + "  R" + rate + "  W" + rate.
            const processWidth = nameWidth + rateWidth * 2 + 6;

            if (root.diskProcesses.length === 0) {
                // Keep the row width so the bubble does not shrink when the
                // last active process goes idle. Non-breaking spaces are not
                // trimmed from the end of the line.
                lines.push(Yassm.I18n.t("common.no_io").padEnd(processWidth, "\u00A0"));
            } else {
                for (let i = 0; i < root.diskProcesses.length; i++) {
                    const entry = root.diskProcesses[i];
                    const name = entry.name.length > nameWidth ? entry.name.slice(0, nameWidth - 1) + "…" : entry.name;

                    lines.push(name.padEnd(nameWidth) + "  R" + formatRateLong(entry.read / 1024).padStart(rateWidth) + "  W" + formatRateLong(entry.write / 1024).padStart(rateWidth));
                }
            }
        }

        return tooltipBlock(Yassm.I18n.t("title.disk"), lines.join("\n"));
    }

    function syncTooltipModel() {
        const lines = root.tooltipContent.lines;

        while (tooltipLineModel.count > lines.length) {
            tooltipLineModel.remove(tooltipLineModel.count - 1);
        }

        for (let i = 0; i < lines.length; i++) {
            if (i >= tooltipLineModel.count) {
                tooltipLineModel.append({
                    lineText: "",
                    lineHeading: false,
                    lineBold: false
                });
            }

            tooltipLineModel.setProperty(i, "lineText", lines[i].text);
            tooltipLineModel.setProperty(i, "lineHeading", lines[i].heading);
            tooltipLineModel.setProperty(i, "lineBold", lines[i].bold);
        }
    }

    function moduleTooltip(key) {
        const metrics = Yassm.SystemMetrics;

        if (key === "load") {
            // Load average on the left, CPU-normalised percentage on the
            // right. Both columns are fixed so the tooltip never jitters.
            const loads = [metrics.load1, metrics.load5, metrics.load15];
            const labels = [" 1 min ", " 5 min ", "15 min "];
            const cores = Math.max(1, Number(metrics.nproc) || 1);
            const lines = [];

            for (let i = 0; i < loads.length; i++) {
                const percent = Math.round(100 * Number(loads[i]) / cores);
                lines.push(labels[i] + formatLoad(loads[i]) + " (" + String(percent).padStart(3, " ") + "%)");
            }

            return tooltipBlock(Yassm.I18n.t("title.load"), lines.join("\n"));
        }

        if (key === "memory") {
            const labels = [Yassm.I18n.t("row.total"), Yassm.I18n.t("row.used"), Yassm.I18n.t("row.available")];
            const values = [formatKibAsGib(metrics.memoryTotalKb), formatKibAsGib(metrics.memoryUsedKb), formatKibAsGib(metrics.memoryAvailableKb)];

            if (root.showExtended) {
                labels.push(Yassm.I18n.t("row.shared"));
                values.push(formatKibAsGib(metrics.memorySharedKb));
                labels.push(Yassm.I18n.t("row.buffer"));
                values.push(formatKibAsGib(metrics.memoryBuffersKb));
                labels.push(Yassm.I18n.t("row.cache"));
                values.push(formatKibAsGib(metrics.memoryCacheKb));
            }
            const showKernel = root.showExtended && metrics.kernelTotalKb > 0;
            const table = processTable(root.processMemory, true);
            const kernelValue = showKernel ? formatKib(metrics.kernelTotalKb) : "";
            // Fixed columns: the process list refreshes every 5 s and the
            // values must not shift when the longest name or value changes.
            const nameWidth = 15;
            const valueWidth = 10;

            const lines = [];
            lines.push(root.centeredMark + root.iconMemory + " " + Yassm.I18n.t("head.data"));

            for (let i = 0; i < labels.length; i++) {
                lines.push(labels[i].padEnd(nameWidth) + "  " + values[i].padStart(valueWidth));
            }

            if (root.showExtended) {
                lines.push("");
                lines.push(root.centeredMark + root.iconLoadHigh + " " + Yassm.I18n.t("head.pressure"));

                const pressure = pressureRows(metrics.memoryPressure10, metrics.memoryPressure60, metrics.memoryPressure300, metrics.memoryPressureFull10, metrics.memoryPressureFull60, metrics.memoryPressureFull300);

                for (let i = 0; i < pressure.length; i++) {
                    lines.push(pressure[i]);
                }
            }

            if (showKernel || root.processMemory.length > 0) {
                lines.push("");
                lines.push(root.centeredMark + root.iconProc + " " + Yassm.I18n.t("head.proc"));
            }

            if (showKernel) {
                lines.push(root.boldMark + Yassm.I18n.t("row.kernel").padEnd(nameWidth) + "  " + kernelValue.padStart(valueWidth));
            }

            if (root.processMemory.length > 0) {
                appendTableRows(lines, table, nameWidth, valueWidth);
            }

            return tooltipBlock(Yassm.I18n.t("title.ram"), lines.join("\n"));
        }

        if (key === "swap") {
            const devices = metrics.swapDevices || [];
            const totalPercent = metrics.swapTotalKb > 0 ? Math.round(100 * metrics.swapUsedKb / metrics.swapTotalKb) : 0;
            const lines = [];

            if (root.showExtended && devices.length > 0) {
                let nameWidth = 0;
                let usedWidth = 0;
                let totalWidth = 0;
                const rows = [];

                for (let i = 0; i < devices.length; i++) {
                    const device = devices[i];
                    const usedText = formatKibAsGib(device.usedKb);
                    const totalText = formatKibAsGib(device.sizeKb);
                    const percent = device.sizeKb > 0 ? Math.round(100 * device.usedKb / device.sizeKb) : 0;

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

                lines.push(root.centeredMark + root.iconSwap + " " + Yassm.I18n.t("head.devices"));

                for (let i = 0; i < rows.length; i++) {
                    const row = rows[i];

                    lines.push(row.name.padEnd(nameWidth) + "  " + row.used.padStart(usedWidth) + " / " + row.total.padStart(totalWidth) + " (" + row.percent + "%)");
                }
            } else {
                lines.push(formatKibAsGib(metrics.swapUsedKb) + " / " + formatKibAsGib(metrics.swapTotalKb) + " (" + totalPercent + "%)");
            }

            if (!root.showExtended) {
                return tooltipBlock(Yassm.I18n.t("title.swap"), lines.join("\n"));
            }

            const zramEntries = [];

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

                const ratio = stats.compressedKb > 0 ? stats.originalKb / stats.compressedKb : 0;

                zramEntries.push({
                    name: base,
                    text: Yassm.I18n.tf("swap.compressed", [formatKib(stats.compressedKb), formatKib(stats.originalKb)]) + (ratio > 0 ? " (" + ratio.toFixed(2) + ":1)" : "") + Yassm.I18n.tf("swap.mem", [formatKib(stats.memKb)])
                });
            }

            if (zramEntries.length > 0) {
                lines.push("");
                lines.push(root.centeredMark + root.iconMemory + " " + Yassm.I18n.t("head.zram"));

                for (let i = 0; i < zramEntries.length; i++) {
                    // With a single zram the name adds nothing; keep it only
                    // when several devices need to be told apart.
                    const prefix = zramEntries.length > 1 ? zramEntries[i].name + ": " : "";

                    lines.push(prefix + zramEntries[i].text);
                }
            }

            if (metrics.hasZswap) {
                const ratio = metrics.zswapCompressedKb > 0 ? metrics.zswapOriginalKb / metrics.zswapCompressedKb : 0;

                lines.push("");
                lines.push(root.centeredMark + root.iconCompress + " " + Yassm.I18n.t("head.zswap"));
                lines.push(Yassm.I18n.tf("swap.compressed", [formatKib(metrics.zswapCompressedKb), formatKib(metrics.zswapOriginalKb)]) + (ratio > 0 ? " (" + ratio.toFixed(2) + ":1)" : ""));
            }

            return tooltipBlock(Yassm.I18n.t("title.swap"), lines.join("\n"));
        }

        if (key === "disk") {
            return mountsTooltip();
        }

        if (key === "cpu") {
            const cores = metrics.corePercents || [];
            const lines = [];

            if (cores.length > 0) {
                lines.push(root.centeredMark + root.iconCpu + " " + Yassm.I18n.t("head.cores"));

                const frequencies = root.showExtended ? (metrics.coreFreqMhz || []) : [];
                let frequencyWidth = 0;

                for (let i = 0; i < frequencies.length; i++) {
                    const mhz = Number(frequencies[i]);

                    if (Number.isFinite(mhz) && mhz > 0) {
                        frequencyWidth = Math.max(frequencyWidth, String(Math.round(mhz)).length);
                    }
                }

                // Two columns fit up to 20 cores; beyond that, add columns so
                // the tooltip never grows past 10 rows.
                const columns = Math.max(2, Math.ceil(cores.length / 10));
                const rows = Math.ceil(cores.length / columns);
                const labelWidth = cores.length >= 100 ? 3 : 2;

                for (let row = 0; row < rows; row++) {
                    const cells = [];

                    for (let column = 0; column < columns; column++) {
                        const index = column * rows + row;

                        if (index < cores.length) {
                            cells.push(coreEntry(String(index + 1), cores[index], labelWidth, frequencies[index], frequencyWidth));
                        }
                    }

                    lines.push(cells.join("     "));
                }
            }

            if (root.showExtended) {
                lines.push("");
                lines.push(root.centeredMark + root.iconLoadHigh + " " + Yassm.I18n.t("head.pressure"));

                const pressure = singlePressureRows(metrics.cpuPressure10, metrics.cpuPressure60, metrics.cpuPressure300);

                for (let i = 0; i < pressure.length; i++) {
                    lines.push(pressure[i]);
                }
            }

            const table = processTable(root.processCpu, false);
            const showKernel = root.showExtended;
            const kernelValue = showKernel ? metrics.kernelPercent.toFixed(1) + "%" : "";
            const nameWidth = 15;
            const valueWidth = 6;

            if (showKernel || root.processCpu.length > 0) {
                if (lines.length > 0) {
                    lines.push("");
                }

                lines.push(root.centeredMark + root.iconProc + " " + Yassm.I18n.t("head.proc"));

                if (showKernel) {
                    lines.push(root.boldMark + Yassm.I18n.t("row.kernel").padEnd(nameWidth) + "  " + kernelValue.padStart(valueWidth));
                }

                if (root.processCpu.length > 0) {
                    appendTableRows(lines, table, nameWidth, valueWidth);
                }
            }

            return tooltipBlock(Yassm.I18n.t("title.cpu"), lines.join("\n"));
        }

        if (key === "gpu") {
            return tooltipBlock(Yassm.I18n.t("title.gpu"), gpu === null ? Yassm.I18n.t("common.unavailable") : Math.round(gpu) + "%");
        }

        if (key === "net" || key === "netDown" || key === "netUp" || key === "netOffline") {
            const metrics = Yassm.SystemMetrics;

            if (!metrics.hasNetwork) {
                return tooltipBlock(Yassm.I18n.t("title.net"), Yassm.I18n.t("common.unavailable"));
            }

            const downRate = formatRateLong(metrics.networkRxKib);
            const upRate = formatRateLong(metrics.networkTxKib);
            const downSession = formatKibAsSize(metrics.networkRxSessionKb);
            const upSession = formatKibAsSize(metrics.networkTxSessionKb);
            // Fixed columns: the session values must not move when a rate
            // crosses a unit or gains a digit.
            const rateWidth = 12;
            const sessionWidth = 11;
            const ifaceIcon = metrics.activeWifi ? root.iconWifi : root.iconEthernet;
            const lines = [root.centeredMark + root.iconSwap + " " + Yassm.I18n.t("head.io"), "↓ " + downRate.padEnd(rateWidth) + "  (" + Yassm.I18n.t("common.session") + " " + downSession.padStart(sessionWidth) + ")", "↑ " + upRate.padEnd(rateWidth) + "  (" + Yassm.I18n.t("common.session") + " " + upSession.padStart(sessionWidth) + ")"];

            lines.push("");
            lines.push(root.centeredMark + ifaceIcon + " " + Yassm.I18n.t("head.interface"));

            let ifaceLine = metrics.networkInterface;

            if (root.showExtended && metrics.ifaceIpv4 !== "") {
                ifaceLine += " · " + metrics.ifaceIpv4;
            }

            if (root.showExtended && metrics.wanIp !== "") {
                ifaceLine += " · " + metrics.wanIp;
            }

            lines.push(ifaceLine);

            if (root.showExtended && metrics.activeWifi) {
                let wifi = metrics.wifiSsid !== "" ? metrics.wifiSsid : Yassm.I18n.t("common.hidden_ssid");

                if (metrics.wifiFreqMhz > 0) {
                    wifi += " · " + Math.round(metrics.wifiFreqMhz) + " MHz";
                }

                if (metrics.wifiLevel < 0) {
                    wifi += " · " + Math.round(metrics.wifiLevel) + " dBm";
                }

                lines.push(wifi);
            }

            return tooltipBlock(Yassm.I18n.t("title.net"), lines.join("\n"));
        }

        if (key === "battery") {
            if (!metrics.hasBattery) {
                return tooltipBlock(Yassm.I18n.t("title.battery"), Yassm.I18n.t("common.unavailable"));
            }

            const lines = [Math.round(metrics.batteryPercent) + "% (" + batteryStateLabel(metrics.batteryStatus) + ")"];

            if (metrics.batteryStatus === "Charging" && metrics.batteryTimeToFull > 0) {
                lines.push(Yassm.I18n.tf("battery.to_full", [formatDuration(metrics.batteryTimeToFull)]));
            } else if (metrics.batteryTimeToEmpty > 0) {
                lines.push(Yassm.I18n.tf("battery.remaining", [formatDuration(metrics.batteryTimeToEmpty)]));
            }

            if (root.showExtended && Number.isFinite(metrics.batteryPowerW) && Math.abs(metrics.batteryPowerW) >= 0.05) {
                const arrow = batteryPowerArrow();

                if (arrow !== "") {
                    lines.push(Math.abs(metrics.batteryPowerW).toFixed(1) + " W " + arrow);
                }
            }

            if (root.showExtended) {
                const health = [];

                if (metrics.batteryHealth > 0) {
                    health.push(Math.round(metrics.batteryHealth) + "%");
                }

                if (metrics.batteryCycles > 0) {
                    health.push(metrics.batteryCycles + " " + Yassm.I18n.t("battery.cycles"));
                }

                if (health.length > 0) {
                    lines.push(Yassm.I18n.t("battery.health") + " " + health.join(" (") + (health.length > 1 ? ")" : ""));
                }
            }

            return tooltipBlock(Yassm.I18n.t("title.battery"), lines.join("\n"));
        }

        if (key === "alerts") {
            const systemUnits = metrics.failedSystemUnits || [];
            const userUnits = metrics.failedUserUnits || [];
            const zombies = metrics.zombieAlerts || [];
            const lines = [];

            if (systemUnits.length > 0) {
                lines.push(root.centeredMark + root.iconServer + " " + Yassm.I18n.t("head.systemd"));
                for (let i = 0; i < systemUnits.length; i++) {
                    lines.push(systemUnits[i]);
                }
            }

            if (userUnits.length > 0) {
                if (lines.length > 0) {
                    lines.push("");
                }

                lines.push(root.centeredMark + root.iconUser + " " + Yassm.I18n.t("head.systemd_user"));
                for (let i = 0; i < userUnits.length; i++) {
                    lines.push(userUnits[i]);
                }
            }

            if (zombies.length > 0) {
                if (lines.length > 0) {
                    lines.push("");
                }

                lines.push(root.centeredMark + root.iconGhost + " " + Yassm.I18n.t("head.zombie"));
                for (let i = 0; i < zombies.length; i++) {
                    lines.push(zombies[i].pid + " " + zombies[i].name + " (" + formatDuration(zombies[i].age) + ")");
                }
            }

            if (metrics.diskAlert) {
                if (lines.length > 0) {
                    lines.push("");
                }

                lines.push(root.centeredMark + root.iconDisk + " " + Yassm.I18n.t("head.disk"));
                lines.push(Yassm.I18n.tf("alerts.disk_usage", [Math.round(metrics.diskPercent)]));
            }

            if (metrics.memoryAlert) {
                if (lines.length > 0) {
                    lines.push("");
                }

                lines.push(root.centeredMark + root.iconMemory + " " + Yassm.I18n.t("head.ram"));
                lines.push(Yassm.I18n.tf("alerts.ram_usage", [Math.round(metrics.memoryPercent)]));
            }

            if (lines.length === 0) {
                lines.push(Yassm.I18n.t("common.no_alerts"));
            }

            return tooltipBlock(Yassm.I18n.t("title.alerts"), lines.join("\n"));
        }

        if (key === "uptime") {
            const bootLabel = Yassm.I18n.t("uptime.boot");
            const install = root.showExtended ? root.installRows(bootLabel) : [];

            if (install.length === 0) {
                return tooltipBlock(Yassm.I18n.t("title.uptime"), bootLabel + " : " + formatUptimeLong(metrics.uptimeSeconds));
            }

            const lines = [bootLabel.padEnd(install.width) + " : " + formatUptimeLong(metrics.uptimeSeconds)].concat(install.lines);

            return tooltipBlock(Yassm.I18n.t("title.uptime"), lines.join("\n"));
        }

        if (key === "temp") {
            const temperatures = metrics.temperatures || [];
            const fans = metrics.fans || [];

            if (temperatures.length === 0 && fans.length === 0) {
                return tooltipBlock(Yassm.I18n.t("title.sensors"), Yassm.I18n.t("common.unavailable"));
            }

            const lines = [];

            if (temperatures.length > 0) {
                lines.push(root.centeredMark + root.iconTemp + " " + Yassm.I18n.t("head.temperatures"));

                for (let i = 0; i < temperatures.length; i++) {
                    lines.push(temperatures[i].celsius.toFixed(1).padStart(4, " ") + " °C (" + temperatures[i].sensor + ")");
                }
            }

            if (fans.length > 0) {
                let nameWidth = 0;
                let rpmWidth = 0;

                for (let i = 0; i < fans.length; i++) {
                    nameWidth = Math.max(nameWidth, fans[i].name.length);
                    rpmWidth = Math.max(rpmWidth, String(Math.round(fans[i].rpm)).length);
                }

                if (lines.length > 0) {
                    lines.push("");
                }

                lines.push(root.centeredMark + root.iconFan + " " + Yassm.I18n.t("head.fans"));

                for (let i = 0; i < fans.length; i++) {
                    lines.push(fans[i].name.padEnd(nameWidth) + "  " + String(Math.round(fans[i].rpm)).padStart(rpmWidth) + " rpm");
                }
            }

            return tooltipBlock(Yassm.I18n.t("title.sensors"), lines.join("\n"));
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
        let nearest = null;
        let nearestCenter = 0;
        let nearestDistance = Infinity;

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

            // The gap between two modules belongs to the nearest one: without
            // this, crossing the gap hides the tooltip and restarts ps.
            const distance = localX < child.x ? child.x - localX : localX - (child.x + child.width);

            if (distance < nearestDistance) {
                nearestDistance = distance;
                nearest = child;
                nearestCenter = origin.x + child.x + child.width / 2;
            }
        }

        if (nearest && nearestDistance <= root.moduleGap) {
            return {
                key: nearest.metricKey,
                center: nearestCenter
            };
        }

        return null;
    }

    function refreshProcesses() {
        if (root.hoveredSegment === "cpu") {
            root.startCpuSnapshot();
        } else if (root.hoveredSegment === "memory") {
            if (!memoryTopProcess.running) {
                memoryTopProcess.running = true;
            }
        } else if (root.hoveredSegment === "disk" && root.showExtended) {
            root.startDiskIo();
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
            root.cpuSnapshot = null;
            root.cpuSnapshotTime = 0;
        } else if (hit.key === "memory") {
            root.processMemory = [];
        } else if (hit.key === "disk" && root.showExtended) {
            root.diskProcesses = [];
            root.diskIoSnapshot = null;
        }

        root.refreshProcesses();

        if (root.showExtended && hit.key.indexOf("net") === 0) {
            Yassm.SystemMetrics.refreshNetworkDetails();
        }

        tooltipAnchor.x = hit.center - tooltipAnchor.width / 2;
    }

    function refreshTooltip() {
        root.hoveredSegment = "";
        root.updateTooltip();
    }

    function hideSegmentTooltip() {
        if (root.hoveredSegment === "cpu") {
            root.cpuSnapshot = null;
            root.cpuSnapshotTime = 0;
        }

        root.hoveredSegment = "";
    }

    function recenterTooltip() {
        if (!root.hoveredSegment) {
            return;
        }

        const children = labelRow.children;

        for (let i = 0; i < children.length; i++) {
            const child = children[i];

            if (child.metricKey === root.hoveredSegment) {
                const origin = labelRow.mapToItem(button, 0, 0);
                tooltipAnchor.x = origin.x + child.x + child.width / 2 - tooltipAnchor.width / 2;
                return;
            }
        }
    }

    function updateSetting(name, value) {
        const current = root.settings || {};
        const entry = {
            id: root.moduleName
        };

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
        entry.showAlerts = root.showAlerts;
        entry.showUptime = root.showUptime;
        entry.extendedTooltips = root.showExtended;
        entry.showNet = root.showNet;
        entry.showTemp = root.showTemp;
        entry.showLoad = root.showLoad;
        entry.showDisk = root.showDisk;
        entry.showColors = root.showColors;
        entry.showBoxes = root.showBoxes;
        entry.iconGap = root.iconGap;
        entry.spacing = root.moduleSpacing;
        entry.refreshInterval = root.refreshInterval;
        entry.slowInterval = root.slowInterval;
        // Older configs still carry the removed Processes interval.
        delete entry.processInterval;
        entry.maxProcesses = root.maxProcesses;
        entry.moduleOrder = root.moduleOrder;
        entry.tempWarm = root.temperatureWarm;
        entry.tempHot = root.temperatureHot;
        entry.tempCritical = root.temperatureCritical;
        entry.percentGreen = root.percentGreen;
        entry.percentOrange = root.percentOrange;
        entry.percentRed = root.percentRed;
        entry.diskGreen = root.diskGreen;
        entry.diskOrange = root.diskOrange;
        entry.diskRed = root.diskRed;
        entry.loadGreen = root.loadGreen;
        entry.loadOrange = root.loadOrange;
        entry.loadRed = root.loadRed;
        entry.netGreen = root.netGreen;
        entry.netOrange = root.netOrange;
        entry.netRed = root.netRed;
        entry.batteryGreen = root.batteryGreen;
        entry.batteryOrange = root.batteryOrange;
        entry.batteryRed = root.batteryRed;
        entry[name] = value;

        root.settings = entry;

        if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function") {
            root.bar.shell.updateEntryInline(root.moduleName, entry);
        }
    }

    function updateGpuFromSysfs() {
        gpuBusyFile.path = root.gpuPath;
        gpuBusyFile.reload();
    }

    function updateGpuFromCommand() {
        gpuProcess.command = ["timeout", "5", "bash", "-c", root.gpuCommand];
        gpuProcess.running = true;
    }

    function detectGpuIfNeeded() {
        if (root.showGpu && root.gpuKind === "none" && !gpuDetector.running) {
            gpuDetector.running = true;
        }
    }

    function launchBtop() {
        if (root.hasBtop) {
            Quickshell.execDetached(["omarchy-launch-or-focus-tui", "btop"]);
            return;
        }

        // btop is not installed: keep the left click useful.
        root.togglePanel();
    }

    // Left click follows the module under the cursor; the gaps and the empty
    // area keep the generic btop target.
    function activateSegment(key) {
        if (key.indexOf("net") === 0) {
            Quickshell.execDetached(["omarchy-shell", "shell", "summon", "omarchy.speedtest"]);
            return;
        }

        if (key === "disk") {
            Quickshell.execDetached(["xdg-open", Quickshell.env("HOME")]);
            return;
        }

        if (key === "battery") {
            Quickshell.execDetached(["omarchy", "menu", "summon", "system"]);
            return;
        }

        if (key === "alerts") {
            Quickshell.execDetached(["omarchy-launch-floating-terminal-with-presentation", "bash", root.alertsViewScriptPath]);
            return;
        }

        root.launchBtop();
    }

    function syncMetricsSubscriptions() {
        const metrics = Yassm.SystemMetrics;
        const extended = root.showExtended;

        metrics.setTemperatureUser(root, root.showTemp);
        metrics.setDiskUser(root, root.showDisk);
        metrics.setSwapUser(root, root.showSwap);
        metrics.setAlertsUser(root, root.showAlerts);
        metrics.setCpuUser(root, root.showCpu);
        metrics.setMemoryUser(root, root.showMemory);
        metrics.setLoadUser(root, root.showLoad);
        metrics.setNetworkUser(root, root.showNet);
        metrics.setUptimeUser(root, root.showUptime);
        metrics.setPressureUser(root, extended && (root.hoveredSegment === "cpu" || root.hoveredSegment === "memory" || root.hoveredSegment === "disk"));
        metrics.setCpuFreqUser(root, extended && root.showCpu && root.hoveredSegment === "cpu");
        metrics.setDiskIoUser(root, extended && root.showDisk && root.hoveredSegment === "disk");
        metrics.setSwapDetailUser(root, extended && root.showSwap && root.hoveredSegment === "swap");
        metrics.setWifiDetailUser(root, extended && root.showNet && root.hoveredSegment === "net");
    }

    function releaseMetricsSubscriptions() {
        const metrics = Yassm.SystemMetrics;

        metrics.setTemperatureUser(root, false);
        metrics.setDiskUser(root, false);
        metrics.setSwapUser(root, false);
        metrics.setAlertsUser(root, false);
        metrics.setCpuUser(root, false);
        metrics.setMemoryUser(root, false);
        metrics.setLoadUser(root, false);
        metrics.setNetworkUser(root, false);
        metrics.setUptimeUser(root, false);
        metrics.setPressureUser(root, false);
        metrics.setCpuFreqUser(root, false);
        metrics.setDiskIoUser(root, false);
        metrics.setSwapDetailUser(root, false);
        metrics.setWifiDetailUser(root, false);
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

        panel.panelX = Math.max(8, Math.min(pos.x + (root.width / 2) - (panel.panelWidth / 2), window.width - panel.panelWidth - 8));

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

    implicitWidth: root.barVertical ? 0 : (emptyLabel.visible ? Math.ceil(emptyLabel.implicitWidth) : Math.ceil(labelRow.width))
    implicitHeight: root.barVertical ? 0 : button.implicitHeight

    FileView {
        id: gpuBusyFile

        printErrors: false
        onLoaded: {
            const raw = text().trim();
            const value = raw === "" ? NaN : Number(raw);

            root.gpu = Number.isFinite(value) ? value : null;
        }
        onLoadFailed: root.gpu = null
    }

    Process {
        id: btopCheck

        command: ["bash", "-c", "command -v btop >/dev/null 2>&1"]

        onExited: function (exitCode, exitStatus) {
            root.hasBtop = exitCode === 0;
        }
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

        stdout: StdioCollector {
            id: gpuOutput
            waitForEnd: true

            onStreamFinished: {
                // nvidia-smi prints one line per GPU; use the first one.
                const first = gpuOutput.text.trim().split("\n")[0];
                const value = first === "" ? NaN : Number(first);

                root.gpu = Number.isFinite(value) ? value : null;
            }
        }

        onExited: function (exitCode, exitStatus) {
            if (exitCode !== 0) {
                root.gpu = null;
            }
        }
    }

    Process {
        id: procSnapshotProcess

        command: ["timeout", "5", "bash", root.procSnapshotPath]

        stdout: StdioCollector {
            id: procSnapshotOutput
            waitForEnd: true

            onStreamFinished: {
                root.applyProcSnapshot(procSnapshotOutput.text);
            }
        }
    }

    Process {
        id: memoryTopProcess

        command: ["timeout", "5", "ps", "-eo", "pid=,ppid=,comm=,rss=", "--sort=-rss"]

        stdout: StdioCollector {
            id: memoryTopOutput
            waitForEnd: true

            onStreamFinished: {
                root.applyProcessMemory(memoryTopOutput.text);
            }
        }
    }

    Process {
        id: diskIoProcess

        command: ["timeout", "5", "bash", root.diskIoScriptPath]

        stdout: StdioCollector {
            id: diskIoOutput
            waitForEnd: true

            onStreamFinished: {
                root.applyDiskIo(diskIoOutput.text);
            }
        }
    }

    // First CPU sample only gives a baseline; take a second one quickly so the
    // tooltip does not stay empty for the whole slow interval.
    Timer {
        id: cpuWarmupTimer
        interval: 1000
        repeat: false

        onTriggered: root.startCpuSnapshot()
    }

    Timer {
        id: diskWarmupTimer
        interval: 1000
        repeat: false

        onTriggered: root.startDiskIo()
    }

    // Keep the process list live while the CPU, RAM or DISK tooltip is open,
    // at the slow background cadence.
    Timer {
        interval: root.slowInterval * 1000
        repeat: true
        running: root.hoveredSegment === "cpu" || root.hoveredSegment === "memory" || (root.hoveredSegment === "disk" && root.showExtended)

        onTriggered: root.refreshProcesses()
    }

    // Last-resort watchdog: a bar park/move may not deliver onExited, and a
    // segment can disappear while the tooltip is open.
    Timer {
        interval: 250
        repeat: true
        running: root.hoveredSegment !== ""

        onTriggered: {
            if (!tooltipTracker.containsMouse || !root.segmentVisible(root.hoveredSegment)) {
                root.hideSegmentTooltip();
            }
        }
    }

    // All bar instances share one sampler; the value is identical for each.
    Binding {
        target: Yassm.SystemMetrics
        property: "fastIntervalMs"
        value: root.refreshInterval * 1000
        restoreMode: Binding.RestoreNone
    }

    Binding {
        target: Yassm.SystemMetrics
        property: "slowIntervalMs"
        value: root.slowInterval * 1000
        restoreMode: Binding.RestoreNone
    }

    Timer {
        interval: root.slowInterval * 1000
        running: root.showGpu && root.gpuKind !== "none"
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
        text: "YASSM"
        labelVisible: false
        tooltipText: ""

        // The bar dispatches clicks to WidgetButton itself (its slot owns the
        // press), so the segment under the cursor is taken from the hover
        // tracker rather than from a MouseArea of ours.
        onPressed: function (buttonCode) {
            if (buttonCode === Qt.LeftButton) {
                root.activateSegment(root.hoveredSegment);
            } else if (buttonCode === Qt.RightButton) {
                root.togglePanel();
            }
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
            text: " "
        }

        Row {
            id: labelRow

            anchors.centerIn: parent
            spacing: root.moduleGap
            onWidthChanged: root.recenterTooltip()

            Repeater {
                model: root.segmentOrder

                Rectangle {
                    id: segmentBox

                    required property string modelData

                    readonly property string metricKey: modelData
                    readonly property int paddingX: metricKey === "alerts" ? (root.showBoxes ? Style.space(8) : Style.space(4)) : (root.showBoxes ? Style.space(4) : 0)
                    readonly property int paddingY: root.showBoxes ? Style.space(2) : 0

                    visible: root.segmentVisible(metricKey)
                    implicitWidth: segmentContent.implicitWidth + paddingX * 2
                    implicitHeight: segmentContent.implicitHeight + paddingY * 2
                    radius: root.showBoxes ? Style.space(root.boxRadius) : 0
                    color: root.showBoxes ? Qt.rgba(button.foreground.r, button.foreground.g, button.foreground.b, 0.03) : "transparent"
                    border.width: root.showBoxes ? root.boxBorder : 0
                    border.color: root.showBoxes ? Qt.rgba(button.foreground.r, button.foreground.g, button.foreground.b, 0.20) : "transparent"

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
                            visible: root.segmentValue(metricKey) !== ""
                        }

                        Text {
                            text: root.segmentValue(metricKey)
                            color: root.segmentColor(metricKey)
                            // No usable GPU source: keep the "--%" readable
                            // but dimmed so it reads as unavailable.
                            opacity: metricKey === "gpu" && root.gpu === null ? 0.45 : 1.0
                            font.family: button.fontFamily
                            font.pixelSize: button.fontSize
                            renderType: Text.NativeRendering
                            visible: root.segmentValue(metricKey) !== ""
                        }
                    }
                }
            }
        }

        Text {
            id: emptyLabel

            anchors.centerIn: parent
            visible: root.segmentCache.length === 0
            text: Yassm.I18n.t("bar.empty")
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

        visible: root.hoveredSegment !== "" && root.segmentVisible(root.hoveredSegment)
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
                let localY = target.height + Style.space(6);

                if (position === "bottom") {
                    localY = -popupHeight - Style.space(6);
                } else if (position === "left") {
                    localX = target.width + Style.space(6);
                    localY = target.height / 2 - popupHeight / 2;
                } else if (position === "right") {
                    localX = -popupWidth - Style.space(6);
                    localY = target.height / 2 - popupHeight / 2;
                }

                const point = barWindow.contentItem.mapFromItem(target, localX, localY);
                widgetTooltipAnchor.rect.x = Math.round(point.x);
                widgetTooltipAnchor.rect.y = Math.round(point.y);
            }
        }

        BorderSurface {
            id: tooltipBubble

            // Round up and keep a pixel of slack: a fractional width made the
            // Wayland surface one pixel narrower than the bubble and clipped
            // the right border (visible on the NET tooltip).
            implicitWidth: Math.ceil(tooltipColumn.implicitWidth + Style.space(20)) + 2
            implicitHeight: Math.ceil(tooltipColumn.implicitHeight + Style.space(14)) + 2
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
                    model: tooltipLineModel

                    Text {
                        required property string lineText
                        required property bool lineHeading
                        required property bool lineBold

                        textFormat: Text.PlainText
                        text: lineText
                        color: lineHeading ? ShellColor.tooltip.text : ShellColor.muted
                        font.family: button.fontFamily
                        font.pixelSize: Style.font.body
                        font.weight: lineHeading || lineBold ? Font.Bold : Font.Normal
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

        function open(): void {
            root.open();
        }
        function close(): void {
            root.close();
        }
        function toggle(): void {
            root.togglePanel();
        }
        function show(): void {
            root.open();
        }
        function hide(): void {
            root.close();
        }
    }

    Component.onCompleted: {
        root.detectGpuIfNeeded();
        root.syncMetricsSubscriptions();
        btopCheck.running = true;
    }
    Component.onDestruction: root.releaseMetricsSubscriptions()
    onShowGpuChanged: root.detectGpuIfNeeded()
    onShowCpuChanged: root.syncMetricsSubscriptions()
    onShowMemoryChanged: root.syncMetricsSubscriptions()
    onShowSwapChanged: root.syncMetricsSubscriptions()
    onShowLoadChanged: root.syncMetricsSubscriptions()
    onShowNetChanged: root.syncMetricsSubscriptions()
    onShowTempChanged: root.syncMetricsSubscriptions()
    onShowDiskChanged: root.syncMetricsSubscriptions()
    onShowAlertsChanged: root.syncMetricsSubscriptions()
    onShowUptimeChanged: root.syncMetricsSubscriptions()
    onShowExtendedChanged: root.syncMetricsSubscriptions()
    Connections {
        target: Yassm.SystemMetrics

        function onNetworkInterfaceChanged() {
            // A tooltip left open across a link change must fetch the new
            // LAN/WAN addresses instead of keeping the previous link's.
            if (root.showExtended && root.hoveredSegment.indexOf("net") === 0) {
                Yassm.SystemMetrics.refreshNetworkDetails();
            }
        }

        function onNetworkDetailsInvalidated() {
            if (root.showExtended && root.hoveredSegment.indexOf("net") === 0) {
                Yassm.SystemMetrics.refreshNetworkDetails();
            }
        }
    }

    onHoveredSegmentChanged: root.syncMetricsSubscriptions()
}
