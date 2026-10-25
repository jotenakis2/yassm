pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

// One sampler for the whole shell. Every bar widget instance reads this
// singleton, so multi-monitor setups don't duplicate /proc reads or findmnt
// processes.
Singleton {
    id: metrics

    readonly property int fastIntervalMs: 1000
    readonly property int diskIntervalMs: 15000

    property int nproc: 1

    property real cpuPercent: 0
    property var previousCpuTimes: null

    property real memoryPercent: 0
    property real memoryTotalKb: 0
    property real memoryUsedKb: 0
    property real kernelTotalKb: 0
    property real kernelReclaimableKb: 0

    property bool hasSwap: false
    property real swapPercent: 0
    property real swapTotalKb: 0
    property real swapUsedKb: 0

    property bool hasZswap: false
    property real zswapCompressedKb: 0
    property real zswapOriginalKb: 0

    property var swapDevices: []
    property var zramDevices: []
    property var zramStats: ({})

    property real load1: 0
    property real load5: 0
    property real load15: 0
    readonly property real loadPercent: Math.max(0, 100 * load1 / nproc)

    property real diskPercent: 0
    property var mounts: []

    property string networkInterface: ""
    property real networkRxKib: 0
    property real networkTxKib: 0
    property real networkRxSessionKb: 0
    property real networkTxSessionKb: 0
    property var networkPrevious: null
    readonly property bool hasNetwork: networkInterface !== ""

    readonly property string temperatureScriptPath: Qt.resolvedUrl("../temperature.sh").toString().replace("file://", "")
    readonly property int temperatureIntervalMs: 10000
    property bool hasTemperature: false
    property real temperatureC: 0
    property var temperatures: []

    readonly property var batteryDevice: {
        const display = UPower.displayDevice;

        if (display && display.isPresent && display.isLaptopBattery) {
            return display;
        }

        const devices = UPower.devices ? UPower.devices.values : [];

        for (let i = 0; i < devices.length; i++) {
            const device = devices[i];

            if (device && device.isPresent && device.isLaptopBattery) {
                return device;
            }
        }

        return null;
    }
    readonly property bool hasBattery: batteryDevice !== null
    readonly property real batteryPercent: hasBattery
        ? Math.max(0, Math.min(100, 100 * (Number(batteryDevice.percentage) || 0)))
        : 0
    readonly property string batteryStatus: hasBattery ? batteryStateName(batteryDevice.state) : ""
    readonly property real batteryTimeToEmpty: hasBattery ? (Number(batteryDevice.timeToEmpty) || 0) : 0
    readonly property real batteryTimeToFull: hasBattery ? (Number(batteryDevice.timeToFull) || 0) : 0
    readonly property real batteryPowerW: hasBattery ? (Number(batteryDevice.changeRate) || 0) : 0
    readonly property bool batteryPlugged: hasBattery && !UPower.onBattery

    function batteryStateName(state) {
        switch (state) {
        case UPowerDeviceState.Charging:
            return "Charging";
        case UPowerDeviceState.Discharging:
            return "Discharging";
        case UPowerDeviceState.FullyCharged:
            return "Full";
        case UPowerDeviceState.Empty:
            return "Empty";
        case UPowerDeviceState.PendingCharge:
            return "Pending charge";
        case UPowerDeviceState.PendingDischarge:
            return "Pending discharge";
        default:
            return "Unknown";
        }
    }

    function applyCpuTimes(content) {
        const firstLine = content.split("\n")[0];

        if (!firstLine || !firstLine.startsWith("cpu")) {
            return;
        }

        const fields = firstLine.trim().split(/\s+/).slice(1).map(Number);

        if (fields.length < 4 || fields.some(function(value) { return !Number.isFinite(value); })) {
            return;
        }

        const idle = fields[3] + fields[4];
        const total = fields.reduce(function(sum, value) {
            return sum + value;
        }, 0);
        const previous = metrics.previousCpuTimes;

        if (previous) {
            const totalDelta = total - previous.total;
            const idleDelta = idle - previous.idle;

            if (totalDelta > 0) {
                metrics.cpuPercent = Math.max(0, Math.min(100, 100 * (totalDelta - idleDelta) / totalDelta));
            }
        }

        metrics.previousCpuTimes = { idle: idle, total: total };
    }

    function applyMemoryInfo(content) {
        const lines = content.split("\n");
        let total = 0;
        let available = 0;
        let swapTotal = 0;
        let swapFree = 0;
        let zswapCompressed = 0;
        let zswapOriginal = 0;
        let slab = 0;
        let sReclaimable = 0;
        let kernelStack = 0;
        let pageTables = 0;

        for (let i = 0; i < lines.length; i++) {
            if (lines[i].startsWith("MemTotal:")) {
                total = Number(lines[i].split(/\s+/)[1]);
            } else if (lines[i].startsWith("MemAvailable:")) {
                available = Number(lines[i].split(/\s+/)[1]);
            } else if (lines[i].startsWith("SwapTotal:")) {
                swapTotal = Number(lines[i].split(/\s+/)[1]);
            } else if (lines[i].startsWith("SwapFree:")) {
                swapFree = Number(lines[i].split(/\s+/)[1]);
            } else if (lines[i].startsWith("Zswap:")) {
                zswapCompressed = Number(lines[i].split(/\s+/)[1]);
            } else if (lines[i].startsWith("Zswapped:")) {
                zswapOriginal = Number(lines[i].split(/\s+/)[1]);
            } else if (lines[i].startsWith("Slab:")) {
                slab = Number(lines[i].split(/\s+/)[1]);
            } else if (lines[i].startsWith("SReclaimable:")) {
                sReclaimable = Number(lines[i].split(/\s+/)[1]);
            } else if (lines[i].startsWith("KernelStack:")) {
                kernelStack = Number(lines[i].split(/\s+/)[1]);
            } else if (lines[i].startsWith("PageTables:")) {
                pageTables = Number(lines[i].split(/\s+/)[1]);
            }
        }

        if (!(total > 0)) {
            return;
        }

        metrics.memoryTotalKb = total;
        metrics.memoryUsedKb = Math.max(0, total - available);
        metrics.memoryPercent = Math.max(0, Math.min(100, 100 * metrics.memoryUsedKb / total));
        metrics.kernelTotalKb = slab + kernelStack + pageTables;
        metrics.kernelReclaimableKb = sReclaimable;

        if (swapTotal > 0) {
            metrics.hasSwap = true;
            metrics.swapTotalKb = swapTotal;
            metrics.swapUsedKb = Math.max(0, swapTotal - swapFree);
            metrics.swapPercent = Math.max(0, Math.min(100, 100 * metrics.swapUsedKb / swapTotal));
        } else {
            metrics.hasSwap = false;
            metrics.swapTotalKb = 0;
            metrics.swapUsedKb = 0;
            metrics.swapPercent = 0;
        }

        metrics.zswapCompressedKb = zswapCompressed;
        metrics.zswapOriginalKb = zswapOriginal;
        metrics.hasZswap = zswapCompressed > 0 || zswapOriginal > 0;
    }

    function applySwapDevices(content) {
        const lines = content.split("\n");
        const devices = [];

        for (let i = 1; i < lines.length; i++) {
            const line = lines[i].trim();

            if (line === "") {
                continue;
            }

            const fields = line.split(/\s+/);

            if (fields.length < 5) {
                continue;
            }

            const name = fields[0].replace(/\\040/g, " ").replace(/\\011/g, "\t");
            const sizeKb = Number(fields[2]);
            const usedKb = Number(fields[3]);

            if (!(sizeKb > 0)) {
                continue;
            }

            const zram = name.startsWith("/dev/zram");

            devices.push({
                name: name,
                zram: zram,
                type: zram ? "zram" : fields[1],
                sizeKb: sizeKb,
                usedKb: Number.isFinite(usedKb) ? usedKb : 0,
                priority: fields[4]
            });
        }

        metrics.swapDevices = devices;

        const zramNames = [];

        for (let i = 0; i < devices.length; i++) {
            if (devices[i].zram) {
                zramNames.push(devices[i].name.split("/").pop());
            }
        }

        if (zramNames.join(",") !== metrics.zramDevices.join(",")) {
            metrics.zramDevices = zramNames;
        }
    }

    function applyZramStat(name, content) {
        const fields = content.trim().split(/\s+/);

        if (fields.length < 3) {
            return;
        }

        const stats = Object.assign({}, metrics.zramStats);

        stats[name] = {
            originalKb: (Number(fields[0]) || 0) / 1024,
            compressedKb: (Number(fields[1]) || 0) / 1024,
            memKb: (Number(fields[2]) || 0) / 1024
        };

        metrics.zramStats = stats;
    }

    function applyLoad(content) {
        const fields = content.trim().split(/\s+/);

        if (fields.length < 3) {
            return;
        }

        metrics.load1 = Number(fields[0]) || 0;
        metrics.load5 = Number(fields[1]) || 0;
        metrics.load15 = Number(fields[2]) || 0;
    }

    // The default route's interface avoids counting VPN/virtual traffic twice.
    function applyNetRoute(content) {
        const lines = content.split("\n");
        let iface = "";

        for (let i = 1; i < lines.length; i++) {
            const fields = lines[i].trim().split(/\s+/);

            if (fields.length >= 2 && fields[1] === "00000000") {
                iface = fields[0];
                break;
            }
        }

        if (iface === metrics.networkInterface) {
            return;
        }

        metrics.networkInterface = iface;
        metrics.networkPrevious = null;
        metrics.networkRxKib = 0;
        metrics.networkTxKib = 0;
        metrics.networkRxSessionKb = 0;
        metrics.networkTxSessionKb = 0;
    }

    function applyNetDev(content) {
        const iface = metrics.networkInterface;

        if (!iface) {
            return;
        }

        const lines = content.split("\n");
        let rx = null;
        let tx = null;

        for (let i = 2; i < lines.length; i++) {
            const line = lines[i];
            const colon = line.indexOf(":");

            if (colon < 0 || line.slice(0, colon).trim() !== iface) {
                continue;
            }

            const fields = line.slice(colon + 1).trim().split(/\s+/);
            rx = Number(fields[0]);
            tx = Number(fields[8]);
            break;
        }

        if (!Number.isFinite(rx) || !Number.isFinite(tx)) {
            return;
        }

        const now = Date.now();
        const previous = metrics.networkPrevious;

        // Date.now() can jump after suspend or NTP adjustment, and link
        // resets can rewind counters; both cases restart the baseline.
        if (previous
                && previous.iface === iface
                && now > previous.time
                && now - previous.time <= 30000
                && rx >= previous.rx
                && tx >= previous.tx) {
            const seconds = (now - previous.time) / 1000;
            const rxDelta = (rx - previous.rx) / 1024;
            const txDelta = (tx - previous.tx) / 1024;
            metrics.networkRxKib = rxDelta / seconds;
            metrics.networkTxKib = txDelta / seconds;
            metrics.networkRxSessionKb += rxDelta;
            metrics.networkTxSessionKb += txDelta;
        } else {
            metrics.networkRxKib = 0;
            metrics.networkTxKib = 0;
        }

        metrics.networkPrevious = {
            iface: iface,
            time: now,
            rx: rx,
            tx: tx
        };
    }

    function unescapeMount(value) {
        return value.replace(/\\x20/g, " ").replace(/\\x5c/g, "\\");
    }

    function applyMounts(content) {
        // Pseudo filesystems are never useful in a disk usage tooltip.
        // Everything else (local, removable, NFS, CIFS, overlay…) is kept.
        const excluded = {
            proc: true,
            sysfs: true,
            devtmpfs: true,
            tmpfs: true,
            devpts: true,
            efivarfs: true,
            securityfs: true,
            cgroup: true,
            cgroup2: true,
            pstore: true,
            bpf: true,
            autofs: true,
            tracefs: true,
            debugfs: true,
            hugetlbfs: true,
            mqueue: true,
            configfs: true,
            fusectl: true,
            ramfs: true,
            binfmt_misc: true,
            rpc_pipefs: true,
            nsfs: true,
            devfs: true
        };

        const lines = content.split("\n");
        const bySource = {};

        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim();

            if (line === "") {
                continue;
            }

            const fields = line.split(/\s+/);

            if (fields.length < 6) {
                continue;
            }

            const target = unescapeMount(fields[0]);
            const source = fields[1].replace(/\[.*\]$/, "");
            const fstype = fields[2];
            const totalBytes = Number(fields[3]);
            const usedBytes = Number(fields[4]);
            const availBytes = Number(fields[5]);

            // AppImage/FUSE scratch mounts land in /tmp, and per-user runtime
            // mounts in /run/user are session-scoped: neither is real storage.
            if (target === "/tmp" || target.startsWith("/tmp/")
                    || target.startsWith("/run/user/")) {
                continue;
            }

            const percent = usedBytes + availBytes > 0
                ? Math.max(0, Math.min(100, Math.ceil(100 * usedBytes / (usedBytes + availBytes))))
                : 0;

            if (!source || excluded[fstype] || !(totalBytes > 0)) {
                continue;
            }

            const entry = {
                target: target,
                source: source,
                fstype: fstype,
                totalBytes: totalBytes,
                usedBytes: usedBytes,
                availBytes: availBytes,
                percent: percent
            };

            // Btrfs subvolumes and bind mounts share a source. Keep the
            // mount itself when it is "/", otherwise keep the first one.
            if (!bySource[source] || target === "/") {
                bySource[source] = entry;
            }
        }

        const list = Object.keys(bySource).map(function(key) {
            return bySource[key];
        });

        if (list.length === 0) {
            return;
        }

        list.sort(function(left, right) {
            return left.target < right.target ? -1 : (left.target > right.target ? 1 : 0);
        });

        metrics.mounts = list;

        for (let i = 0; i < list.length; i++) {
            if (list[i].target !== "/") {
                continue;
            }

            metrics.diskPercent = list[i].percent;
            break;
        }
    }

    function applyTemperatures(content) {
        const entries = [];
        const lines = content.split("\n");

        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim();

            if (line === "") {
                continue;
            }

            const tab = line.indexOf("\t");
            const raw = Number((tab >= 0 ? line.slice(0, tab) : line).trim());

            if (!Number.isFinite(raw) || !(raw > 0) || !(raw < 200000)) {
                continue;
            }

            const sensor = tab >= 0 ? line.slice(tab + 1).trim() : "";
            entries.push({
                celsius: raw / 1000,
                sensor: sensor || "unknown sensor"
            });
        }

        entries.sort(function(left, right) {
            return right.celsius - left.celsius;
        });

        metrics.temperatures = entries;
        metrics.hasTemperature = entries.length > 0;
        metrics.temperatureC = entries.length > 0 ? entries[0].celsius : 0;
    }

    FileView {
        id: procStat
        path: "/proc/stat"
        onLoaded: metrics.applyCpuTimes(text())
    }

    FileView {
        id: procMemInfo
        path: "/proc/meminfo"
        onLoaded: metrics.applyMemoryInfo(text())
    }

    FileView {
        id: procLoadAvg
        path: "/proc/loadavg"
        onLoaded: metrics.applyLoad(text())
    }

    FileView {
        id: procNetRoute
        path: "/proc/net/route"
        onLoaded: metrics.applyNetRoute(text())
    }

    FileView {
        id: procNetDev
        path: "/proc/net/dev"
        onLoaded: metrics.applyNetDev(text())
    }

    FileView {
        id: procSwaps
        path: "/proc/swaps"
        onLoaded: metrics.applySwapDevices(text())
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

            metrics.nproc = Math.max(1, count);
        }
    }

    Instantiator {
        model: metrics.zramDevices

        delegate: Item {
            id: zramDelegate

            required property string modelData

            FileView {
                id: zramStat

                path: "/sys/block/" + zramDelegate.modelData + "/mm_stat"
                printErrors: false
                onLoaded: metrics.applyZramStat(zramDelegate.modelData, text())
            }

            Timer {
                interval: 10000
                running: true
                repeat: true
                triggeredOnStart: true

                onTriggered: zramStat.reload()
            }
        }
    }

    Timer {
        interval: metrics.fastIntervalMs
        running: true
        repeat: true

        onTriggered: {
            // Parsing happens in onLoaded, never by reading text() right
            // after reload() (that would return stale data).
            procStat.reload();
            procMemInfo.reload();
            procLoadAvg.reload();
            procNetRoute.reload();
            procNetDev.reload();
            procSwaps.reload();
        }
    }

    Process {
        id: mountProcess

        command: ["findmnt", "-rn", "-b", "-o", "TARGET,SOURCE,FSTYPE,SIZE,USED,AVAIL"]

        stdout: StdioCollector {
            id: mountOutput
            waitForEnd: true
            onStreamFinished: metrics.applyMounts(mountOutput.text)
        }

        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) {
                console.warn("yassm: findmnt exited with", exitCode);
            }
        }
    }

    Process {
        id: temperatureProcess

        command: ["bash", metrics.temperatureScriptPath]

        stdout: StdioCollector {
            id: temperatureOutput
            waitForEnd: true
            onStreamFinished: metrics.applyTemperatures(temperatureOutput.text)
        }

        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) {
                console.warn("yassm: temperature scan exited with", exitCode);
            }
        }
    }

    Timer {
        interval: metrics.temperatureIntervalMs
        running: true
        repeat: true
        triggeredOnStart: true

        onTriggered: temperatureProcess.running = true
    }

    Timer {
        interval: metrics.diskIntervalMs
        running: true
        repeat: true
        triggeredOnStart: true

        onTriggered: mountProcess.running = true
    }
}
