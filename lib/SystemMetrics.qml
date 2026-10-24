pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

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

    property bool hasSwap: false
    property real swapPercent: 0
    property real swapTotalKb: 0
    property real swapUsedKb: 0

    property real load1: 0
    property real load5: 0
    property real load15: 0
    readonly property real loadPercent: Math.max(0, Math.min(100, 100 * load1 / nproc))

    property real diskPercent: 0
    property var mounts: []

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

        for (let i = 0; i < lines.length; i++) {
            if (lines[i].startsWith("MemTotal:")) {
                total = Number(lines[i].split(/\s+/)[1]);
            } else if (lines[i].startsWith("MemAvailable:")) {
                available = Number(lines[i].split(/\s+/)[1]);
            } else if (lines[i].startsWith("SwapTotal:")) {
                swapTotal = Number(lines[i].split(/\s+/)[1]);
            } else if (lines[i].startsWith("SwapFree:")) {
                swapFree = Number(lines[i].split(/\s+/)[1]);
            }
        }

        if (!(total > 0)) {
            return;
        }

        metrics.memoryTotalKb = total;
        metrics.memoryUsedKb = Math.max(0, total - available);
        metrics.memoryPercent = Math.max(0, Math.min(100, 100 * metrics.memoryUsedKb / total));

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

            if (!source || excluded[fstype] || !(totalBytes > 0)) {
                continue;
            }

            const entry = {
                target: target,
                source: source,
                fstype: fstype,
                totalBytes: totalBytes,
                usedBytes: usedBytes,
                availBytes: availBytes
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

            const denominator = list[i].usedBytes + list[i].availBytes;
            metrics.diskPercent = denominator > 0
                ? Math.max(0, Math.min(100, Math.ceil(100 * list[i].usedBytes / denominator)))
                : 0;
            break;
        }
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

    Timer {
        interval: metrics.diskIntervalMs
        running: true
        repeat: true
        triggeredOnStart: true

        onTriggered: mountProcess.running = true
    }
}
