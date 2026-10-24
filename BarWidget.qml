import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import QtQuick.Controls
import QtQuick.Layouts

BarWidget {
    id: root

    moduleName: "io.github.jotenakis2.yassm"

    readonly property string detectScriptPath: Qt.resolvedUrl("detect-gpu.sh").toString().replace("file://", "")
    readonly property string diskScriptPath: Qt.resolvedUrl("disk.sh").toString().replace("file://", "")

    readonly property int fastIntervalMs: 1000
    readonly property int gpuIntervalMs: 10000
    readonly property int diskIntervalMs: 15000

    property real cpu: 0
    property real memory: 0
    property real memoryTotalKb: 0
    property real memoryUsedKb: 0
    property var swap: null
    property real swapTotalKb: 0
    property real swapUsedKb: 0
    property real load1: 0
    property real load5: 0
    property real load15: 0
    property int nproc: 1
    readonly property real load: Math.max(0, Math.min(100, 100 * load1 / nproc))
    property real disk: 0
    property real diskUsedKb: 0
    property real diskTotalKb: 0
    property var gpu: null

    property string hoveredSegment: ""

    property string gpuKind: "none"
    property string gpuPath: ""
    property string gpuCommand: ""

    property var previousCpuTimes: null

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
        const segments = [];

        if (showCpu) {
            const text = iconCpu + " " + pad(Math.round(cpu)) + "%";
            segments.push({ key: "cpu", text: text, glyphs: text.length - 1 });
        }

        if (showLoad) {
            const text = iconLoad + " " + pad(Math.round(load)) + "%";
            segments.push({ key: "load", text: text, glyphs: text.length - 1 });
        }

        if (showGpu) {
            const text = iconGpu + " " + pad(gpu === null ? null : Math.round(gpu)) + "%";
            segments.push({ key: "gpu", text: text, glyphs: text.length - 1 });
        }

        if (showMemory) {
            const text = iconMemory + " " + pad(Math.round(memory)) + "%";
            segments.push({ key: "memory", text: text, glyphs: text.length - 1 });
        }

        if (showSwap && swap !== null) {
            const text = iconSwap + " " + pad(Math.round(swap)) + "%";
            segments.push({ key: "swap", text: text, glyphs: text.length - 1 });
        }

        if (showDisk) {
            const text = iconDisk + " " + pad(Math.round(disk)) + "%";
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

    function formatGib(kilobytes) {
        const value = Number(kilobytes) / 1048576;
        return (Number.isFinite(value) ? value : 0).toFixed(2) + " GiB";
    }

    function moduleTooltip(key) {
        if (key === "load") {
            return "Load average (1/5/15 min)\n"
                + " 1 min " + formatLoad(load1) + "\n"
                + " 5 min " + formatLoad(load5) + "\n"
                + "15 min " + formatLoad(load15);
        }

        if (key === "memory") {
            return "RAM\n" + formatGib(memoryUsedKb) + " / " + formatGib(memoryTotalKb);
        }

        if (key === "swap") {
            return "Swap\n" + formatGib(swapUsedKb) + " / " + formatGib(swapTotalKb);
        }

        if (key === "disk") {
            return "Disk /\n" + formatGib(diskUsedKb) + " / " + formatGib(diskTotalKb);
        }

        if (key === "cpu") {
            return "CPU\n" + Math.round(cpu) + "%";
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

    function readCpuTimes() {
        procStat.reload();

        const firstLine = procStat.text().split("\n")[0];
        const fields = firstLine.trim().split(/\s+/).slice(1).map(Number);

        const idle = fields[3] + fields[4];
        const total = fields.reduce(function(sum, value) {
            return sum + value;
        }, 0);

        return {
            idle: idle,
            total: total
        };
    }

    function updateCpu() {
        const current = root.readCpuTimes();

        if (root.previousCpuTimes) {
            const totalDelta = current.total - root.previousCpuTimes.total;
            const idleDelta = current.idle - root.previousCpuTimes.idle;

            if (totalDelta > 0) {
                root.cpu = Math.max(0, Math.min(100, 100 * (totalDelta - idleDelta) / totalDelta));
            }
        }

        root.previousCpuTimes = current;
    }

    function updateMemory() {
        procMemInfo.reload();

        const lines = procMemInfo.text().split("\n");
        let total = 0;
        let available = 0;
        let swapTotal = 0;
        let swapFree = 0;

        for (let i = 0; i < lines.length; i++) {
            if (lines[i].startsWith("MemTotal:")) {
                total = Number(lines[i].split(/\s+/)[1]);
            }

            if (lines[i].startsWith("MemAvailable:")) {
                available = Number(lines[i].split(/\s+/)[1]);
            }

            if (lines[i].startsWith("SwapTotal:")) {
                swapTotal = Number(lines[i].split(/\s+/)[1]);
            }

            if (lines[i].startsWith("SwapFree:")) {
                swapFree = Number(lines[i].split(/\s+/)[1]);
            }
        }

        root.memoryTotalKb = total;
        root.memoryUsedKb = Math.max(0, total - available);
        root.swapTotalKb = swapTotal;
        root.swapUsedKb = Math.max(0, swapTotal - swapFree);

        if (total > 0) {
            root.memory = Math.max(0, Math.min(100, 100 * (total - available) / total));
        }

        if (swapTotal > 0) {
            root.swap = Math.max(0, Math.min(100, 100 * (swapTotal - swapFree) / swapTotal));
        } else {
            root.swap = null;
        }
    }

    function updateLoad() {
        procLoadAvg.reload();

        const fields = procLoadAvg.text().trim().split(/\s+/);
        root.load1 = Number(fields[0]) || 0;
        root.load5 = Number(fields[1]) || 0;
        root.load15 = Number(fields[2]) || 0;
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

    readonly property bool opened: settingsWindow.visible

    function open() {
        if (settingsWindow.visible) {
            return;
        }

        const barWindow = root.QsWindow.window;
        if (barWindow && barWindow.screen) {
            settingsWindow.screen = barWindow.screen;
        }

        const pos = root.mapToItem(null, 0, 0);

        settingsWindow.panelX = Math.max(
            8,
            Math.min(
                pos.x + (root.width / 2) - (settingsPanel.width / 2),
                root.Window.window.width - settingsPanel.width - 8
            )
        );

        settingsWindow.panelY = root.Window.window.height - settingsWindow.barVisibleOffset;

        if (root.bar && typeof root.bar.requestPopout === "function") {
            root.bar.requestPopout(root);
        }

        settingsWindow.visible = true;
    }

    function close() {
        if (!settingsWindow.visible) {
            return;
        }

        settingsWindow.visible = false;

        if (root.bar && typeof root.bar.releasePopout === "function") {
            root.bar.releasePopout(root);
        }
    }

    function closeForPopoutSwitch() {
        root.close();
    }

    function togglePanel() {
        if (settingsWindow.visible) {
            root.close();
        } else {
            root.open();
        }
    }

    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    FileView {
        id: procStat
        path: "/proc/stat"
    }

    FileView {
        id: procMemInfo
        path: "/proc/meminfo"
    }

    FileView {
        id: procLoadAvg
        path: "/proc/loadavg"
    }

    FileView {
        id: procCpuInfo
        path: "/proc/cpuinfo"

        onLoaded: {
            const lines = text().split("\n");
            let count = 0;

            for (let i = 0; i < lines.length; i++) {
                if (lines[i].startsWith("processor")) {
                    count++;
                }
            }

            root.nproc = Math.max(1, count);
        }
    }

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
        id: diskProcess

        command: ["bash", root.diskScriptPath]

        stdout: SplitParser {
            onRead: data => {
                const fields = data.trim().split(/\s+/);

                if (fields.length < 3) {
                    return;
                }

                root.diskUsedKb = Number(fields[0]) || 0;
                root.diskTotalKb = Number(fields[1]) || 0;
                root.disk = Number(fields[2]) || 0;
            }
        }
    }

    Timer {
        interval: root.fastIntervalMs
        running: true
        repeat: true
        triggeredOnStart: true

        onTriggered: {
            root.updateCpu();
            root.updateMemory();
            root.updateLoad();
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

    Timer {
        interval: root.diskIntervalMs
        running: true
        repeat: true
        triggeredOnStart: true

        onTriggered: diskProcess.running = true
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


    PanelWindow {
        id: settingsWindow

        property real panelX: 0
        property real panelY: 0
        readonly property int barVisibleOffset: 30
        
        visible: false
        color: "transparent"

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        readonly property font panelFont: Qt.application.font

        MouseArea {
            anchors.fill: parent

            onPressed: {
                root.close();
            }
        }

        BorderSurface {
            id: settingsPanel

            width: 280
            height: settingsColumn.implicitHeight + 32
            radius: Style.cornerRadius >= 0 ? Style.cornerRadius : 12
            color: ShellColor.popups.background
            borderSpec: Border.surfaceSpec("menu", "border", ShellColor.popups.border, Style.normalBorderWidth)
            palette.windowText: ShellColor.popups.text
            antialiasing: true
            smooth: true

            x: settingsWindow.panelX
            y: settingsWindow.panelY

            MouseArea {
                anchors.fill: parent

                onPressed: {
                    // Empêche la fermeture lorsqu'on clique dans le panneau
                }
            }

            ColumnLayout {
                id: settingsColumn

                anchors.fill: parent
                anchors.margins: 16
                spacing: 4

                Label {
                    Layout.fillWidth: true
                    text: "YASSM"
                    palette.windowText: ShellColor.popups.text
                    font.family: settingsWindow.panelFont.family
                    font.pointSize: settingsWindow.panelFont.pointSize + 1

                    bottomPadding: 8
                }

                CheckBox {
                    Layout.fillWidth: true
                    text: "CPU"
                    font.family: settingsWindow.panelFont.family
                    font.pointSize: settingsWindow.panelFont.pointSize
                    checked: root.showCpu

                    onClicked: {
                        root.updateSetting("showCpu", checked);
                    }
                }

                CheckBox {
                    Layout.fillWidth: true
                    text: "Load"
                    font.family: settingsWindow.panelFont.family
                    font.pointSize: settingsWindow.panelFont.pointSize
                    checked: root.showLoad

                    onClicked: {
                        root.updateSetting("showLoad", checked);
                    }
                }

                CheckBox {
                    Layout.fillWidth: true
                    text: "GPU"
                    font.family: settingsWindow.panelFont.family
                    font.pointSize: settingsWindow.panelFont.pointSize
                    checked: root.showGpu

                    onClicked: {
                        root.updateSetting("showGpu", checked);
                    }
                }

                CheckBox {
                    Layout.fillWidth: true
                    text: "Memory"
                    font.family: settingsWindow.panelFont.family
                    font.pointSize: settingsWindow.panelFont.pointSize
                    checked: root.showMemory

                    onClicked: {
                        root.updateSetting("showMemory", checked);
                    }
                }

                CheckBox {
                    Layout.fillWidth: true
                    text: "Swap"
                    font.family: settingsWindow.panelFont.family
                    font.pointSize: settingsWindow.panelFont.pointSize
                    checked: root.showSwap

                    onClicked: {
                        root.updateSetting("showSwap", checked);
                    }
                }

                CheckBox {
                    Layout.fillWidth: true
                    text: "Disk (root partition)"
                    font.family: settingsWindow.panelFont.family
                    font.pointSize: settingsWindow.panelFont.pointSize
                    checked: root.showDisk

                    onClicked: {
                        root.updateSetting("showDisk", checked);
                    }
                }
            }
        }
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
