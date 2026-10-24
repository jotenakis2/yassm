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
    property bool showLoad: setting("showLoad", true)
    property bool showDisk: setting("showDisk", true)

    readonly property string iconCpu: String.fromCodePoint(0xF0EE0)
    readonly property string iconMemory: String.fromCodePoint(0xF035B)
    readonly property string iconSwap: String.fromCodePoint(0xF04E2)
    readonly property string iconGpu: String.fromCodePoint(0xF08AE)
    readonly property string iconLoad: String.fromCodePoint(0xF04C5)
    readonly property string iconDisk: String.fromCodePoint(0xF02CA)

    // All module icons are astral-plane Nerd Font glyphs: one rendered glyph,
    // two UTF-16 code units. The rest of each segment is ASCII. This keeps
    // glyph counting allocation-free at each refresh.
    readonly property var segmentCache: {
        const metrics = Yassm.SystemMetrics;
        const segments = [];

        if (showCpu) {
            const text = iconCpu + " " + pad(Math.round(metrics.cpuPercent)) + "%";
            segments.push({ key: "cpu", text: text, glyphs: text.length - 1 });
        }

        if (showLoad) {
            const text = iconLoad + " " + pad(Math.round(metrics.loadPercent)) + "%";
            segments.push({ key: "load", text: text, glyphs: text.length - 1 });
        }

        if (showGpu) {
            const text = iconGpu + " " + pad(gpu === null ? null : Math.round(gpu)) + "%";
            segments.push({ key: "gpu", text: text, glyphs: text.length - 1 });
        }

        if (showMemory) {
            const text = iconMemory + " " + pad(Math.round(metrics.memoryPercent)) + "%";
            segments.push({ key: "memory", text: text, glyphs: text.length - 1 });
        }

        if (showSwap && metrics.hasSwap) {
            const text = iconSwap + " " + pad(Math.round(metrics.swapPercent)) + "%";
            segments.push({ key: "swap", text: text, glyphs: text.length - 1 });
        }

        if (showDisk) {
            const text = iconDisk + " " + pad(Math.round(metrics.diskPercent)) + "%";
            segments.push({ key: "disk", text: text, glyphs: text.length - 1 });
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

    function formatBytesAsGib(bytes) {
        const value = Number(bytes) / 1073741824;
        return (Number.isFinite(value) ? value : 0).toFixed(2) + " GiB";
    }

    function mountsTooltip() {
        const mounts = Yassm.SystemMetrics.mounts;

        if (!mounts || mounts.length === 0) {
            return "Disk\nUnavailable";
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

        return "Disk\n" + lines.join("\n");
    }

    function moduleTooltip(key) {
        const metrics = Yassm.SystemMetrics;

        if (key === "load") {
            return "Load average (1/5/15 min)\n"
                + " 1 min " + formatLoad(metrics.load1) + "\n"
                + " 5 min " + formatLoad(metrics.load5) + "\n"
                + "15 min " + formatLoad(metrics.load15);
        }

        if (key === "memory") {
            return "RAM\n" + formatKibAsGib(metrics.memoryUsedKb) + " / " + formatKibAsGib(metrics.memoryTotalKb);
        }

        if (key === "swap") {
            return "Swap\n" + formatKibAsGib(metrics.swapUsedKb) + " / " + formatKibAsGib(metrics.swapTotalKb);
        }

        if (key === "disk") {
            return mountsTooltip();
        }

        if (key === "cpu") {
            return "CPU\n" + Math.round(metrics.cpuPercent) + "%";
        }

        if (key === "gpu") {
            return "GPU\n" + (gpu === null ? "Unavailable" : Math.round(gpu) + "%");
        }

        return "";
    }

    function segmentHitAt(x) {
        const segments = segmentCache;
        const labelWidth = button.labelWidth;

        if (segments.length === 0 || labelWidth <= 0) {
            return null;
        }

        let textLength = 0;
        for (let i = 0; i < segments.length; i++) {
            textLength += segments[i].glyphs;
        }
        textLength += 2 * (segments.length - 1);

        // The bar font is monospace; mapping pixel x to a glyph index avoids
        // maintaining one hover area per segment.
        const charWidth = labelWidth / textLength;
        const startX = (button.width - labelWidth) / 2;
        const localX = x - startX;

        if (localX < 0 || localX > labelWidth) {
            return null;
        }

        const charIndex = Math.floor(localX / charWidth);
        let offset = 0;

        for (let i = 0; i < segments.length; i++) {
            const glyphs = segments[i].glyphs;

            if (charIndex >= offset && charIndex < offset + glyphs) {
                return {
                    key: segments[i].key,
                    center: startX + (offset + glyphs / 2) * charWidth
                };
            }

            offset += glyphs + 2;
        }

        return null;
    }

    function updateTooltip() {
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
        entry.showLoad = root.showLoad;
        entry.showDisk = root.showDisk;
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
        tooltipText: ""

        onPressed: function(buttonCode) {
            root.togglePanel();
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
