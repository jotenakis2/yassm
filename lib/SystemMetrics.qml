pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import Quickshell.Networking

// One sampler for the whole shell. Every bar widget instance reads this
// singleton, so multi-monitor setups don't duplicate /proc reads or findmnt
// processes.
Singleton {
    id: metrics

    property int fastIntervalMs: 1000
    property int slowIntervalMs: 10000

    property int nproc: 1

    property real cpuPercent: 0
    property real kernelPercent: 0
    property var previousCpuTimes: null
    property var corePercents: []
    property var previousCoreTimes: null

    property real memoryPercent: 0
    property real memoryTotalKb: 0
    property real memoryUsedKb: 0
    property real memoryAvailableKb: 0
    property real memoryBuffersKb: 0
    property real memoryCacheKb: 0
    property real memorySharedKb: 0
    property real kernelTotalKb: 0

    property bool hasSwap: false
    property real swapPercent: 0
    property real swapTotalKb: 0
    property real swapUsedKb: 0

    // zswap can be enabled while its pool is empty (after the reclaimed pages
    // were swapped back in); keep the section visible whenever it is active.
    property bool zswapEnabled: false
    property bool hasZswap: zswapEnabled || zswapCompressedKb > 0 || zswapOriginalKb > 0
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
    property var networkMounts: []
    property var networkMountUsers: []
    readonly property bool networkMountEnabled: networkMountUsers.length > 0

    // One ping at a time, only while a NET tooltip is open.
    property var pingUsers: []
    readonly property bool pingEnabled: pingUsers.length > 0
    property real pingMs: 0
    property bool pingMeasured: false
    property real diskReadKib: 0
    property real diskWriteKib: 0
    property var diskIoPrevious: null
    property real diskIoPreviousTime: 0

    property real memoryPressure10: 0
    property real memoryPressure60: 0
    property real memoryPressure300: 0
    property real memoryPressureFull10: 0
    property real memoryPressureFull60: 0
    property real memoryPressureFull300: 0
    property real ioPressure10: 0
    property real ioPressure60: 0
    property real ioPressure300: 0
    property real cpuPressure10: 0
    property real cpuPressure60: 0
    property real cpuPressure300: 0
    property real ioPressureFull10: 0
    property real ioPressureFull60: 0
    property real ioPressureFull300: 0

    // Reference lists: each bar instance registers while a module is enabled.
    // The expensive samplers only run while at least one instance needs them.
    property var temperatureUsers: []
    property var diskUsers: []
    property var swapUsers: []
    property var alertsUsers: []
    property var cpuUsers: []
    property var memoryUsers: []
    property var loadUsers: []
    property var networkUsers: []
    property var uptimeUsers: []
    property var pressureUsers: []
    property var cpuFreqUsers: []
    property var diskIoUsers: []
    property var swapDetailUsers: []
    property var wifiDetailUsers: []
    readonly property bool temperatureEnabled: temperatureUsers.length > 0
    readonly property bool diskEnabled: diskUsers.length > 0
    readonly property bool swapEnabled: swapUsers.length > 0
    readonly property bool alertsEnabled: alertsUsers.length > 0
    readonly property bool cpuEnabled: cpuUsers.length > 0
    readonly property bool memoryEnabled: memoryUsers.length > 0
    readonly property bool loadEnabled: loadUsers.length > 0
    readonly property bool networkEnabled: networkUsers.length > 0
    readonly property bool uptimeEnabled: uptimeUsers.length > 0
    readonly property bool pressureEnabled: pressureUsers.length > 0
    readonly property bool cpuFreqEnabled: cpuFreqUsers.length > 0
    readonly property bool diskIoEnabled: diskIoUsers.length > 0
    readonly property bool swapDetailEnabled: swapDetailUsers.length > 0
    readonly property bool wifiDetailEnabled: wifiDetailUsers.length > 0
    readonly property bool fastEnabled: cpuEnabled || memoryEnabled || swapEnabled || loadEnabled || networkEnabled

    function withUser(users, widget, enabled) {
        const next = users.filter(function (item) {
            return item !== widget;
        });

        if (enabled) {
            next.push(widget);
        }

        return next;
    }

    function setTemperatureUser(widget, enabled) {
        metrics.temperatureUsers = withUser(metrics.temperatureUsers, widget, enabled);
    }

    function setDiskUser(widget, enabled) {
        metrics.diskUsers = withUser(metrics.diskUsers, widget, enabled);
    }

    function setPingUser(widget, enabled) {
        const wasEnabled = metrics.pingEnabled;

        metrics.pingUsers = withUser(metrics.pingUsers, widget, enabled);

        if (enabled && !wasEnabled) {
            // Show -- until this opening's first reply.
            metrics.pingMeasured = false;
            metrics.pingMs = 0;
        }
    }

    function applyPing(content) {
        // The response line is localised ("time=" / "temps="), but the RTT
        // summary keeps the min/avg/max/mdev layout. Use its average.
        const match = String(content || "").match(/=\s*[0-9]+(?:[.,][0-9]+)?\/([0-9]+(?:[.,][0-9]+)?)\//);

        if (match) {
            const value = Number(match[1].replace(",", "."));

            if (Number.isFinite(value) && value > 0) {
                metrics.pingMs = value;
                metrics.pingMeasured = true;
                return;
            }
        }

        metrics.pingMs = 0;
        metrics.pingMeasured = true;
    }

    function setNetworkMountUser(widget, enabled) {
        const wasEnabled = metrics.networkMountEnabled;

        metrics.networkMountUsers = withUser(metrics.networkMountUsers, widget, enabled);

        if (enabled && !wasEnabled) {
            // Query only when the disk tooltip opens: clear the previous rows
            // and fetch fresh ones, without a periodic network statfs.
            metrics.networkMounts = [];
            networkMountProcess.running = true;
        } else if (!enabled && !metrics.networkMountEnabled) {
            metrics.networkMounts = [];
        }
    }

    function setSwapUser(widget, enabled) {
        metrics.swapUsers = withUser(metrics.swapUsers, widget, enabled);
    }

    function setAlertsUser(widget, enabled) {
        metrics.alertsUsers = withUser(metrics.alertsUsers, widget, enabled);
    }

    function setCpuUser(widget, enabled) {
        metrics.cpuUsers = withUser(metrics.cpuUsers, widget, enabled);
    }

    function setMemoryUser(widget, enabled) {
        metrics.memoryUsers = withUser(metrics.memoryUsers, widget, enabled);
    }

    function setLoadUser(widget, enabled) {
        metrics.loadUsers = withUser(metrics.loadUsers, widget, enabled);
    }

    function setNetworkUser(widget, enabled) {
        const wasEnabled = metrics.networkEnabled;

        metrics.networkUsers = withUser(metrics.networkUsers, widget, enabled);

        // Do not make the bar wait for the next 5 s tick when NET comes back.
        if (enabled && !wasEnabled) {
            procNetRoute.reload();
            procNetIpv6Route.reload();
        }
    }

    function setUptimeUser(widget, enabled) {
        const wasEnabled = metrics.uptimeEnabled;

        metrics.uptimeUsers = withUser(metrics.uptimeUsers, widget, enabled);

        if (enabled && !wasEnabled) {
            procUptime.reload();
        }
    }

    function setPressureUser(widget, enabled) {
        const wasEnabled = metrics.pressureEnabled;

        metrics.pressureUsers = withUser(metrics.pressureUsers, widget, enabled);

        if (enabled && !wasEnabled) {
            memoryPressureFile.reload();
            ioPressureFile.reload();
            cpuPressureFile.reload();
        }
    }

    function setCpuFreqUser(widget, enabled) {
        metrics.cpuFreqUsers = withUser(metrics.cpuFreqUsers, widget, enabled);
    }

    function setDiskIoUser(widget, enabled) {
        const wasEnabled = metrics.diskIoEnabled;

        metrics.diskIoUsers = withUser(metrics.diskIoUsers, widget, enabled);

        // The rate needs two samples: read now, then once more shortly after
        // so the tooltip is not empty during the first detail tick.
        if (enabled && !wasEnabled) {
            // Do not average the first rate over the gap since the last
            // hover: start a fresh baseline, then let the 1 s warm-up give
            // the first real rate.
            metrics.diskIoPrevious = null;
            metrics.diskIoPreviousTime = 0;
            procDiskStats.reload();
            diskIoWarmup.restart();
        }
    }

    function setSwapDetailUser(widget, enabled) {
        const wasEnabled = metrics.swapDetailEnabled;

        metrics.swapDetailUsers = withUser(metrics.swapDetailUsers, widget, enabled);

        if (enabled && !wasEnabled) {
            procSwaps.reload();
            zswapEnabledFile.reload();
        }
    }

    function setWifiDetailUser(widget, enabled) {
        const wasEnabled = metrics.wifiDetailEnabled;

        metrics.wifiDetailUsers = withUser(metrics.wifiDetailUsers, widget, enabled);

        if (enabled && !wasEnabled) {
            procWireless.reload();

            if (metrics.activeWifi) {
                wifiFreqProcess.running = true;
            }
        }
    }

    property string networkInterface: ""
    property string networkRouteV4: ""
    property string networkRouteV6: ""
    property real networkRxKib: 0
    property real networkTxKib: 0
    property real networkRxSessionKb: 0
    property real networkTxSessionKb: 0
    property var networkPrevious: null
    readonly property bool hasNetwork: networkInterface !== ""
    property real wifiLevel: 0

    readonly property var wifiNetwork: {
        const devices = modelValues(Networking.devices);

        for (let i = 0; i < devices.length; i++) {
            const device = devices[i];

            if (!device || device.type !== DeviceType.Wifi) {
                continue;
            }

            const networks = modelValues(device.networks);

            for (let j = 0; j < networks.length; j++) {
                if (networks[j] && networks[j].connected) {
                    return networks[j];
                }
            }
        }

        return null;
    }
    readonly property string wifiSsid: wifiNetwork && wifiNetwork.name ? String(wifiNetwork.name) : ""

    // The Wi-Fi helpers must follow the interface actually carrying the
    // default route: a laptop can keep a Wi-Fi association while Ethernet is
    // the active link, and then no Wi-Fi value should be read or shown.
    readonly property bool activeWifi: {
        const wifi = wifiNetwork;

        return wifi !== null && wifi.device !== null && wifi.device !== undefined && wifi.device.name === networkInterface && networkInterface !== "";
    }

    readonly property string wifiFreqScriptPath: decodeURIComponent(Qt.resolvedUrl("../wifi-freq.sh").toString().replace("file://", ""))
    property real wifiFreqMhz: 0

    // Interface addresses are only fetched while the NET tooltip is open:
    // the LAN address from iproute2, the public one from ipify (cached).
    property string ifaceIpv4: ""
    property string wanIp: ""
    property real wanIpUpdatedAt: 0

    // Emitted when the cached addresses no longer describe the current link.
    signal networkDetailsInvalidated

    readonly property string temperatureScriptPath: decodeURIComponent(Qt.resolvedUrl("../temperature.sh").toString().replace("file://", ""))
    property bool hasTemperature: false
    property real temperatureC: 0
    property var temperatures: []
    property var fans: []

    readonly property string cpuFreqScriptPath: decodeURIComponent(Qt.resolvedUrl("../cpu-freq.sh").toString().replace("file://", ""))
    property var coreFreqMhz: []
    property real uptimeSeconds: 0

    readonly property string installDateScriptPath: decodeURIComponent(Qt.resolvedUrl("../install-date.sh").toString().replace("file://", ""))
    property string installDate: ""
    property real installEpoch: 0

    readonly property string depsScriptPath: decodeURIComponent(Qt.resolvedUrl("../deps.sh").toString().replace("file://", ""))
    property var missingDeps: []
    readonly property var missingRequiredDeps: missingDeps.filter(function (dep) {
        return dep.kind === "required";
    })

    readonly property string alertsScriptPath: decodeURIComponent(Qt.resolvedUrl("../alerts.sh").toString().replace("file://", ""))
    readonly property int alertsIntervalMs: 60000
    property var failedSystemUnits: []
    property var failedUserUnits: []
    property var zombieAlerts: []
    readonly property bool hasSystemFailure: failedSystemUnits.length > 0 || failedUserUnits.length > 0
    readonly property bool hasZombies: zombieAlerts.length > 0
    readonly property bool diskAlert: diskEnabled && Math.round(diskPercent) >= 95
    readonly property bool memoryAlert: memoryEnabled && Math.round(memoryPercent) >= 95
    readonly property bool hasAlerts: hasSystemFailure || hasZombies || diskAlert || memoryAlert

    // Quickshell models are untyped from qmllint's point of view; keep the
    // single "values" access here so only one known warning remains.
    function modelValues(model) {
        return model ? model.values : [];
    }

    readonly property var batteryDevice: {
        const display = UPower.displayDevice;

        if (display && display.isPresent && display.isLaptopBattery) {
            return display;
        }

        const devices = modelValues(UPower.devices);

        for (let i = 0; i < devices.length; i++) {
            const device = devices[i];

            if (device && device.isPresent && device.isLaptopBattery) {
                return device;
            }
        }

        return null;
    }
    readonly property bool hasBattery: batteryDevice !== null
    readonly property real batteryPercent: hasBattery ? Math.max(0, Math.min(100, 100 * (Number(batteryDevice.percentage) || 0))) : 0
    readonly property string batteryStatus: hasBattery ? batteryStateName(batteryDevice.state) : ""
    readonly property real batteryTimeToEmpty: hasBattery ? (Number(batteryDevice.timeToEmpty) || 0) : 0
    readonly property real batteryTimeToFull: hasBattery ? (Number(batteryDevice.timeToFull) || 0) : 0
    readonly property real batteryPowerW: hasBattery ? (Number(batteryDevice.changeRate) || 0) : 0
    readonly property bool batteryPlugged: hasBattery && !UPower.onBattery

    // The aggregate DisplayDevice exposes percentage and power but leaves
    // nativePath and healthPercentage empty; the real battery device carries
    // them, so health and cycle count read from that one.
    readonly property var batteryDetailDevice: {
        const devices = modelValues(UPower.devices);

        for (let i = 0; i < devices.length; i++) {
            const device = devices[i];

            if (device && device.isPresent && device.isLaptopBattery && device.nativePath !== "") {
                return device;
            }
        }

        return batteryDevice;
    }
    readonly property real batteryHealth: batteryDetailDevice ? (Number(batteryDetailDevice.healthPercentage) || 0) : 0
    readonly property string batteryCyclePath: batteryDetailDevice && batteryDetailDevice.nativePath ? "/sys/class/power_supply/" + batteryDetailDevice.nativePath + "/cycle_count" : ""
    property int batteryCycles: 0

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
        const lines = content.split("\n");
        let aggregate = null;
        const cores = [];

        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim();

            if (!line.startsWith("cpu")) {
                break;
            }

            const fields = line.split(/\s+/);
            const name = fields[0];
            const values = fields.slice(1).map(Number);

            if (values.length < 4 || values.some(function (value) {
                return !Number.isFinite(value);
            })) {
                continue;
            }

            const idle = values[3] + (values[4] || 0);
            const kernel = (values[2] || 0) + (values[5] || 0) + (values[6] || 0);

            // guest/guest_nice (fields 8-9) are already included in user/nice:
            // adding them again would inflate the total and understate CPU %.
            const total = values.slice(0, 8).reduce(function (sum, value) {
                return sum + value;
            }, 0);

            if (name === "cpu") {
                aggregate = {
                    idle: idle,
                    kernel: kernel,
                    total: total
                };
            } else {
                cores.push({
                    idle: idle,
                    total: total
                });
            }
        }

        if (!aggregate) {
            return;
        }

        if (cores.length > 0) {
            metrics.nproc = cores.length;
        }

        const previous = metrics.previousCpuTimes;

        if (previous) {
            const totalDelta = aggregate.total - previous.total;
            const idleDelta = aggregate.idle - previous.idle;
            const kernelDelta = aggregate.kernel - previous.kernel;

            if (totalDelta > 0) {
                metrics.cpuPercent = Math.max(0, Math.min(100, 100 * (totalDelta - idleDelta) / totalDelta));
                metrics.kernelPercent = Math.max(0, Math.min(100, 100 * kernelDelta / totalDelta));
            }
        }

        metrics.previousCpuTimes = aggregate;

        const previousCores = metrics.previousCoreTimes;
        const percents = [];

        if (previousCores && previousCores.length === cores.length) {
            for (let i = 0; i < cores.length; i++) {
                const totalDelta = cores[i].total - previousCores[i].total;
                const idleDelta = cores[i].idle - previousCores[i].idle;

                if (totalDelta > 0) {
                    percents.push(Math.max(0, Math.min(100, 100 * (totalDelta - idleDelta) / totalDelta)));
                } else {
                    percents.push(0);
                }
            }
        } else {
            for (let i = 0; i < cores.length; i++) {
                percents.push(0);
            }
        }

        metrics.corePercents = percents;
        metrics.previousCoreTimes = cores;
    }

    function applyMemoryInfo(content) {
        const lines = content.split("\n");
        let total = 0;
        let available = NaN;
        let memFree = 0;
        let swapTotal = 0;
        let swapFree = 0;
        let zswapCompressed = 0;
        let zswapOriginal = 0;
        let buffers = 0;
        let cached = 0;
        let shmem = 0;
        let slab = 0;
        let sReclaimable = 0;
        let kernelStack = 0;
        let pageTables = 0;
        let vmallocUsed = 0;
        let percpu = 0;

        for (let i = 0; i < lines.length; i++) {
            if (lines[i].startsWith("MemTotal:")) {
                total = Number(lines[i].split(/\s+/)[1]);
            } else if (lines[i].startsWith("MemAvailable:")) {
                available = Number(lines[i].split(/\s+/)[1]);
            } else if (lines[i].startsWith("MemFree:")) {
                memFree = Number(lines[i].split(/\s+/)[1]);
            } else if (lines[i].startsWith("SwapTotal:")) {
                swapTotal = Number(lines[i].split(/\s+/)[1]);
            } else if (lines[i].startsWith("SwapFree:")) {
                swapFree = Number(lines[i].split(/\s+/)[1]);
            } else if (lines[i].startsWith("Zswap:")) {
                zswapCompressed = Number(lines[i].split(/\s+/)[1]);
            } else if (lines[i].startsWith("Zswapped:")) {
                zswapOriginal = Number(lines[i].split(/\s+/)[1]);
            } else if (lines[i].startsWith("Buffers:")) {
                buffers = Number(lines[i].split(/\s+/)[1]);
            } else if (lines[i].startsWith("Cached:")) {
                cached = Number(lines[i].split(/\s+/)[1]);
            } else if (lines[i].startsWith("Shmem:")) {
                shmem = Number(lines[i].split(/\s+/)[1]);
            } else if (lines[i].startsWith("Slab:")) {
                slab = Number(lines[i].split(/\s+/)[1]);
            } else if (lines[i].startsWith("SReclaimable:")) {
                sReclaimable = Number(lines[i].split(/\s+/)[1]);
            } else if (lines[i].startsWith("KernelStack:")) {
                kernelStack = Number(lines[i].split(/\s+/)[1]);
            } else if (lines[i].startsWith("PageTables:")) {
                pageTables = Number(lines[i].split(/\s+/)[1]);
            } else if (lines[i].startsWith("VmallocUsed:")) {
                vmallocUsed = Number(lines[i].split(/\s+/)[1]);
            } else if (lines[i].startsWith("Percpu:")) {
                percpu = Number(lines[i].split(/\s+/)[1]);
            }
        }

        if (!(total > 0)) {
            return;
        }

        function safe(value) {
            return Number.isFinite(value) ? value : 0;
        }

        total = safe(total);
        memFree = safe(memFree);
        swapTotal = safe(swapTotal);
        swapFree = safe(swapFree);
        zswapCompressed = safe(zswapCompressed);
        zswapOriginal = safe(zswapOriginal);
        buffers = safe(buffers);
        cached = safe(cached);
        shmem = safe(shmem);
        slab = safe(slab);
        sReclaimable = safe(sReclaimable);
        kernelStack = safe(kernelStack);
        pageTables = safe(pageTables);
        vmallocUsed = safe(vmallocUsed);
        percpu = safe(percpu);

        // MemAvailable is authoritative; fall back to the classic
        // MemFree + Buffers + Cached + SReclaimable estimate if it is missing
        // or malformed (older kernels, truncated read).
        let availableKb = Number(available);

        if (!Number.isFinite(availableKb) || availableKb < 0 || availableKb > total) {
            availableKb = memFree + buffers + cached + sReclaimable;
        }

        availableKb = Math.max(0, Math.min(total, availableKb));

        metrics.memoryTotalKb = total;
        metrics.memoryUsedKb = Math.max(0, total - availableKb);
        metrics.memoryAvailableKb = availableKb;
        metrics.memoryPercent = Math.max(0, Math.min(100, 100 * metrics.memoryUsedKb / total));
        // Buffer and Cache are shown separately; Cache keeps SReclaimable so
        // Buffer + Cache still matches the classic Buff/cache total.
        metrics.memoryBuffersKb = buffers;
        metrics.memoryCacheKb = cached + sReclaimable;
        metrics.memorySharedKb = shmem;
        // SReclaimable is already counted in Cache: exclude it from the
        // kernel line so the two rows do not show the same memory twice.
        metrics.kernelTotalKb = Math.max(0, slab - sReclaimable) + kernelStack + pageTables + vmallocUsed + percpu;

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

            const name = fields[0].replace(/\\040/g, " ").replace(/\\011/g, "\t").replace(/\\134/g, "\\").replace(/\\012/g, "\n");
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
                usedKb: Number.isFinite(usedKb) ? usedKb : 0
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
        let bestMetric = Infinity;

        for (let i = 1; i < lines.length; i++) {
            const fields = lines[i].trim().split(/\s+/);

            if (fields.length < 8 || fields[1] !== "00000000") {
                continue;
            }

            // Flags is hexadecimal; bit 0 is RTF_UP. Metric is decimal and
            // decides between several default routes (Ethernet vs Wi-Fi).
            const flags = parseInt(fields[3], 16);
            const metric = Number(fields[6]);

            // Loopback has no link of its own: a default route parked on it
            // (VPN leftovers, partial teardown) means "offline", not "LAN".
            if (fields[0] === "lo" || !(flags & 1) || !Number.isFinite(metric)) {
                continue;
            }

            if (metric < bestMetric) {
                bestMetric = metric;
                iface = fields[0];
            }
        }

        metrics.networkRouteV4 = iface;
        applyNetworkRoute();
    }

    function applyNetIpv6Route(content) {
        const lines = content.split("\n");
        const zero = "00000000000000000000000000000000";
        let iface = "";
        let bestMetric = Infinity;

        for (let i = 0; i < lines.length; i++) {
            const fields = lines[i].trim().split(/\s+/);

            if (fields.length < 10 || fields[0] !== zero || fields[1] !== "00") {
                continue;
            }

            // The kernel keeps an "unreachable default" on lo with all
            // RTF_* flags cleared when there is no IPv6 gateway; only an UP
            // route is usable. Loopback is never a real uplink either.
            const metric = parseInt(fields[5], 16);
            const flags = parseInt(fields[8], 16);

            if (fields[9] === "lo" || !(flags & 1) || !Number.isFinite(metric)) {
                continue;
            }

            if (metric < bestMetric) {
                bestMetric = metric;
                iface = fields[9];
            }
        }

        metrics.networkRouteV6 = iface;
        applyNetworkRoute();
    }

    function applyNetworkRoute() {
        // Prefer the IPv4 default route, then an IPv6 default route. This
        // keeps the module visible on IPv6-only networks.
        const iface = metrics.networkRouteV4 || metrics.networkRouteV6;

        if (iface === metrics.networkInterface) {
            return;
        }

        metrics.networkInterface = iface;
        metrics.networkPrevious = null;
        metrics.networkRxKib = 0;
        metrics.networkTxKib = 0;
        // Addresses belong to the previous link: drop them so the tooltip
        // never shows the old LAN or WAN address on a new connection.
        metrics.ifaceIpv4 = "";
        metrics.wanIp = "";
        metrics.wanIpUpdatedAt = 0;
        metrics.wifiLevel = 0;
        // Session totals span the whole shell session: keep them across
        // interface changes, as documented.
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
        if (previous && previous.iface === iface && now > previous.time && now - previous.time <= 30000 && rx >= previous.rx && tx >= previous.tx) {
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

    function parseMounts(content) {
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
            if (target === "/tmp" || target.startsWith("/tmp/") || target.startsWith("/run/user/")) {
                continue;
            }

            const percent = usedBytes + availBytes > 0 ? Math.max(0, Math.min(100, Math.ceil(100 * usedBytes / (usedBytes + availBytes)))) : 0;

            if (!source || excluded[fstype] || !(totalBytes > 0)) {
                continue;
            }

            // Container image layers and Snap packages are not useful storage
            // entries and can flood the tooltip with dozens of duplicates.
            if (fstype === "squashfs" || (fstype === "overlay" && target !== "/")) {
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

        const list = Object.keys(bySource).map(function (key) {
            return bySource[key];
        });

        list.sort(function (left, right) {
            return left.target < right.target ? -1 : (left.target > right.target ? 1 : 0);
        });

        return list;
    }

    function applyMounts(content) {
        const list = metrics.parseMounts(content);

        if (list.length === 0) {
            return;
        }

        metrics.mounts = list;

        for (let i = 0; i < list.length; i++) {
            if (list[i].target !== "/") {
                continue;
            }

            metrics.diskPercent = list[i].percent;
            break;
        }
    }

    // NFS/CIFS are queried separately with a hard timeout, so a dead server
    // can never delay the local mounts or the tooltip.
    function applyNetworkMounts(content) {
        metrics.networkMounts = metrics.parseMounts(content);
    }

    function applyTemperatures(content) {
        const entries = [];
        const fans = [];
        const lines = content.split("\n");

        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim();

            if (line === "") {
                continue;
            }

            if (line.startsWith("fan\t")) {
                const fields = line.split("\t");
                const rpm = Number(fields[1]);

                if (Number.isFinite(rpm) && rpm >= 0) {
                    fans.push({
                        name: fields[2] || "fan",
                        rpm: rpm
                    });
                }

                continue;
            }

            const tab = line.indexOf("\t");
            const raw = Number((tab >= 0 ? line.slice(0, tab) : line).trim());

            if (!Number.isFinite(raw) || raw <= 0 || raw >= 200000) {
                continue;
            }

            const sensor = tab >= 0 ? line.slice(tab + 1).trim() : "";
            entries.push({
                celsius: raw / 1000,
                sensor: sensor || I18n.t("common.unknown_sensor")
            });
        }

        entries.sort(function (left, right) {
            return right.celsius - left.celsius;
        });

        // Several unlabeled sensors can share one device name; keep the
        // hottest reading per name so the tooltip shows each device once.
        const seen = {};
        const unique = [];

        for (let i = 0; i < entries.length; i++) {
            const sensor = entries[i].sensor;

            if (seen[sensor]) {
                continue;
            }

            seen[sensor] = true;
            unique.push(entries[i]);
        }

        metrics.temperatures = unique;
        metrics.fans = fans;
        metrics.hasTemperature = unique.length > 0;
        metrics.temperatureC = unique.length > 0 ? unique[0].celsius : 0;
    }

    function applyAlerts(content) {
        const systemUnits = [];
        const userUnits = [];
        const zombies = [];
        const lines = String(content || "").split("\n");

        for (let i = 0; i < lines.length; i++) {
            const line = lines[i];

            if (line === "") {
                continue;
            }

            const fields = line.split("\t");
            const kind = fields[0];
            const value = fields[1] || "";

            if (kind === "system" && value !== "") {
                systemUnits.push(value);
            } else if (kind === "user" && value !== "") {
                userUnits.push(value);
            } else if (kind === "zombie") {
                const pid = Number(value);
                const age = Number(fields[3]);

                if (Number.isFinite(pid) && Number.isFinite(age)) {
                    zombies.push({
                        pid: pid,
                        name: fields[2] || "?",
                        age: age
                    });
                }
            }
        }

        systemUnits.sort();
        userUnits.sort();
        zombies.sort(function (left, right) {
            return right.age - left.age;
        });

        metrics.failedSystemUnits = systemUnits;
        metrics.failedUserUnits = userUnits;
        metrics.zombieAlerts = zombies;
    }

    function applyDiskIo(content) {
        const now = Date.now();
        const current = {};
        const lines = content.split("\n");
        const wholeDisk = /^(nvme\d+n\d+|sd[a-z]+|vd[a-z]+|mmcblk\d+|xvd[a-z]+|dasd[a-z]+)$/;

        for (let i = 0; i < lines.length; i++) {
            const fields = lines[i].trim().split(/\s+/);

            if (fields.length < 10 || !wholeDisk.test(fields[2])) {
                continue;
            }

            const read = Number(fields[5]);
            const write = Number(fields[9]);

            if (Number.isFinite(read) && Number.isFinite(write)) {
                current[fields[2]] = {
                    read: read,
                    write: write
                };
            }
        }

        const previous = metrics.diskIoPrevious;
        const previousTime = metrics.diskIoPreviousTime;

        if (previous && previousTime > 0 && now > previousTime) {
            const elapsed = (now - previousTime) / 1000;
            let readSectors = 0;
            let writeSectors = 0;

            for (const name in current) {
                const before = previous[name];

                if (!before || current[name].read < before.read || current[name].write < before.write) {
                    continue;
                }

                readSectors += current[name].read - before.read;
                writeSectors += current[name].write - before.write;
            }

            metrics.diskReadKib = readSectors * 512 / 1024 / elapsed;
            metrics.diskWriteKib = writeSectors * 512 / 1024 / elapsed;
        } else {
            metrics.diskReadKib = 0;
            metrics.diskWriteKib = 0;
        }

        metrics.diskIoPrevious = current;
        metrics.diskIoPreviousTime = now;
    }

    function applyPressure(content) {
        const values = {
            some: {
                avg10: 0,
                avg60: 0,
                avg300: 0
            },
            full: {
                avg10: 0,
                avg60: 0,
                avg300: 0
            }
        };
        const lines = String(content || "").split("\n");

        for (let l = 0; l < lines.length; l++) {
            const fields = lines[l].trim().split(/\s+/);
            const kind = fields[0];

            // CPU pressure only exposes a "some" line; memory and I/O have
            // both. Missing lines simply stay at zero.
            if (kind !== "some" && kind !== "full") {
                continue;
            }

            for (let i = 1; i < fields.length; i++) {
                const match = fields[i].match(/^(avg10|avg60|avg300)=([0-9.]+)$/);

                if (match) {
                    values[kind][match[1]] = Number(match[2]) || 0;
                }
            }
        }

        return values;
    }

    function applyMemoryPressure(content) {
        const values = applyPressure(content);

        metrics.memoryPressure10 = values.some.avg10;
        metrics.memoryPressure60 = values.some.avg60;
        metrics.memoryPressure300 = values.some.avg300;
        metrics.memoryPressureFull10 = values.full.avg10;
        metrics.memoryPressureFull60 = values.full.avg60;
        metrics.memoryPressureFull300 = values.full.avg300;
    }

    function applyCpuPressure(content) {
        const values = applyPressure(content);

        // CPU pressure only has a "some" line: "full" would mean no task at
        // all is running, which the kernel does not define.
        metrics.cpuPressure10 = values.some.avg10;
        metrics.cpuPressure60 = values.some.avg60;
        metrics.cpuPressure300 = values.some.avg300;
    }

    function applyIoPressure(content) {
        const values = applyPressure(content);

        metrics.ioPressure10 = values.some.avg10;
        metrics.ioPressure60 = values.some.avg60;
        metrics.ioPressure300 = values.some.avg300;
        metrics.ioPressureFull10 = values.full.avg10;
        metrics.ioPressureFull60 = values.full.avg60;
        metrics.ioPressureFull300 = values.full.avg300;
    }

    function applyWireless(content) {
        const iface = metrics.networkInterface;
        const lines = content.split("\n");
        let level = 0;

        if (iface !== "") {
            for (let i = 2; i < lines.length; i++) {
                const colon = lines[i].indexOf(":");

                if (colon < 0 || lines[i].slice(0, colon).trim() !== iface) {
                    continue;
                }

                const fields = lines[i].slice(colon + 1).trim().split(/\s+/);
                level = Number.parseFloat(fields[2]) || 0;
                break;
            }
        }

        metrics.wifiLevel = level;
    }

    function applyIfaceIp(content) {
        const fields = String(content || "").trim().split(/\s+/);

        for (let i = 0; i < fields.length - 1; i++) {
            if (fields[i] === "inet") {
                metrics.ifaceIpv4 = fields[i + 1].split("/")[0];
                return;
            }
        }

        metrics.ifaceIpv4 = "";
    }

    function applyWanIp(content) {
        const value = String(content || "").trim();

        // Keep the previous address on a failed lookup, drop anything that is
        // not shaped like an IP (error pages, empty output).
        if (/^[0-9a-fA-F:.]{3,45}$/.test(value)) {
            metrics.wanIp = value;
        }
    }

    function refreshNetworkDetails() {
        if (metrics.networkInterface === "") {
            return;
        }

        ifaceIpProcess.running = true;

        // Opening the tooltip should not show a level up to 5 s old or a
        // frequency up to 30 s old: refresh both immediately, then let the
        // periodic timers keep them current while the tooltip stays open.
        if (metrics.activeWifi) {
            procWireless.reload();
            wifiFreqProcess.running = true;
        }

        const now = Date.now();

        if (now - metrics.wanIpUpdatedAt > 300000) {
            metrics.wanIpUpdatedAt = now;
            wanIpProcess.running = true;
        }
    }

    function applyWifiFreq(content) {
        const value = Number(String(content).trim());
        metrics.wifiFreqMhz = Number.isFinite(value) && value > 0 ? value : 0;
    }

    function applyCpuFreq(content) {
        const lines = String(content || "").split("\n");
        const frequencies = [];

        for (let i = 0; i < lines.length; i++) {
            const fields = lines[i].trim().split(/\s+/);

            if (fields.length < 2) {
                continue;
            }

            const index = Number(fields[0]);
            const mhz = Number(fields[1]);

            if (Number.isInteger(index) && index >= 0 && index < 1024 && Number.isFinite(mhz) && mhz > 0) {
                frequencies[index] = mhz;
            }
        }

        metrics.coreFreqMhz = frequencies;
    }

    function applyUptime(content) {
        const value = Number(String(content).trim().split(/\s+/)[0]);
        metrics.uptimeSeconds = Number.isFinite(value) ? value : 0;
    }

    function applyDeps(content) {
        const missing = [];
        const lines = String(content || "").split("\n");

        for (let i = 0; i < lines.length; i++) {
            const fields = lines[i].split("\t");

            if (fields.length < 2) {
                continue;
            }

            const kind = fields[0];
            const name = fields[1] || "";

            if ((kind === "required" || kind === "optional") && name !== "") {
                missing.push({
                    kind: kind,
                    name: name,
                    purpose: fields[2] || ""
                });
            }
        }

        metrics.missingDeps = missing;
    }

    function applyInstallDate(content) {
        // install-date.sh prints the locale-formatted date on the first line
        // (e.g. "9 sept. 2026") and the matching Unix timestamp on the second.
        const parts = String(content || "").split("\n");
        const value = (parts[0] || "").trim();
        const stamp = Number((parts[1] || "").trim());

        metrics.installDate = value !== "" && value.length <= 24 ? value : "";
        metrics.installEpoch = Number.isFinite(stamp) && stamp > 0 ? stamp : 0;
    }

    function applyBatteryCycles(content) {
        const value = Number(String(content).trim());
        metrics.batteryCycles = Number.isFinite(value) ? value : 0;
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
        id: zswapEnabledFile
        path: "/sys/module/zswap/parameters/enabled"
        printErrors: false
        onLoaded: metrics.zswapEnabled = String(text()).trim() === "Y"
        onLoadFailed: metrics.zswapEnabled = false
    }

    FileView {
        id: procLoadAvg
        path: "/proc/loadavg"
        onLoaded: metrics.applyLoad(text())
    }

    FileView {
        id: memoryPressureFile
        path: "/proc/pressure/memory"
        printErrors: false
        onLoaded: metrics.applyMemoryPressure(text())
    }

    FileView {
        id: ioPressureFile
        path: "/proc/pressure/io"
        printErrors: false
        onLoaded: metrics.applyIoPressure(text())
    }

    FileView {
        id: cpuPressureFile
        path: "/proc/pressure/cpu"
        printErrors: false
        onLoaded: metrics.applyCpuPressure(text())
    }

    FileView {
        id: procDiskStats
        path: "/proc/diskstats"
        onLoaded: metrics.applyDiskIo(text())
    }

    FileView {
        id: procWireless
        path: "/proc/net/wireless"
        printErrors: false
        onLoaded: metrics.applyWireless(text())
    }

    FileView {
        id: procUptime
        path: "/proc/uptime"
        onLoaded: metrics.applyUptime(text())
    }

    FileView {
        id: batteryCyclesFile
        path: metrics.batteryCyclePath
        printErrors: false
        onLoaded: metrics.applyBatteryCycles(text())
        onLoadFailed: metrics.batteryCycles = 0
    }

    FileView {
        id: procNetRoute
        path: "/proc/net/route"
        onLoaded: metrics.applyNetRoute(text())
    }

    FileView {
        id: procNetIpv6Route
        path: "/proc/net/ipv6_route"
        onLoaded: metrics.applyNetIpv6Route(text())
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
                interval: metrics.slowIntervalMs
                running: metrics.swapDetailEnabled
                repeat: true
                triggeredOnStart: true

                onTriggered: zramStat.reload()
            }
        }
    }

    // Slow loop: the bar values beyond the fast ones (disk usage, temperature,
    // uptime) plus the tooltip details that do not need Fast (PSI, swap
    // devices, zram/zswap). Alerts keep their own 60 s timer and battery
    // cycles their hourly one.
    Timer {
        interval: metrics.slowIntervalMs
        running: metrics.diskEnabled || metrics.temperatureEnabled || metrics.uptimeEnabled || metrics.pressureEnabled || metrics.swapDetailEnabled
        repeat: true
        triggeredOnStart: true

        onTriggered: {
            if (metrics.diskEnabled) {
                mountProcess.running = true;
            }

            if (metrics.pressureEnabled) {
                memoryPressureFile.reload();
                ioPressureFile.reload();
                cpuPressureFile.reload();
            }

            if (metrics.swapDetailEnabled) {
                procSwaps.reload();
                zswapEnabledFile.reload();
            }

            if (metrics.temperatureEnabled) {
                temperatureProcess.running = true;
            }

            if (metrics.uptimeEnabled) {
                procUptime.reload();
            }
        }
    }

    // Tooltip-only fast data (disk I/O rates, Wi-Fi signal): read only while
    // the matching tooltip is open.
    Timer {
        interval: metrics.fastIntervalMs
        running: metrics.diskIoEnabled || metrics.wifiDetailEnabled
        repeat: true
        triggeredOnStart: true

        onTriggered: {
            if (metrics.diskIoEnabled) {
                procDiskStats.reload();
            }

            if (metrics.wifiDetailEnabled && metrics.activeWifi) {
                procWireless.reload();
            }
        }
    }

    Timer {
        id: diskIoWarmup

        interval: 1000
        repeat: false

        onTriggered: procDiskStats.reload()
    }

    Timer {
        // Cycle count only changes when a full cycle completes, so an hourly
        // refresh is plenty; the FileView already loads once the path exists.
        interval: 3600000
        running: metrics.batteryCyclePath !== ""
        repeat: true

        onTriggered: batteryCyclesFile.reload()
    }

    Timer {
        interval: metrics.fastIntervalMs
        running: metrics.fastEnabled
        repeat: true
        triggeredOnStart: true

        onTriggered: {
            // Parsing happens in onLoaded, never by reading text() right
            // after reload() (that would return stale data). Each file is
            // only read while a module that consumes it is visible.
            if (metrics.cpuEnabled || metrics.loadEnabled) {
                procStat.reload();
            }

            if (metrics.memoryEnabled || metrics.swapEnabled) {
                procMemInfo.reload();
            }

            if (metrics.loadEnabled) {
                procLoadAvg.reload();
            }

            if (metrics.networkEnabled) {
                procNetRoute.reload();
                procNetIpv6Route.reload();
                procNetDev.reload();
            }
        }
    }

    Process {
        id: mountProcess

        command: ["timeout", "5", "findmnt", "-rn", "-b", "-o", "TARGET,SOURCE,FSTYPE,SIZE,USED,AVAIL", "-t", "ext2,ext3,ext4,btrfs,xfs,f2fs,vfat,exfat,ntfs,ntfs3,iso9660,udf,zfs,bcachefs,overlay,fuseblk,jfs,reiserfs,nilfs2,hfs,hfsplus,ufs"]

        stdout: StdioCollector {
            id: mountOutput
            waitForEnd: true
            onStreamFinished: metrics.applyMounts(mountOutput.text)
        }

        onExited: function (exitCode, exitStatus) {
            if (exitCode !== 0 && exitCode !== 124) {
                console.warn("yassm: findmnt exited with", exitCode);
            }
        }
    }

    Timer {
        // Follow the Slow sampling setting (5–30 s, default 10 s).
        interval: metrics.slowIntervalMs
        running: metrics.pingEnabled
        repeat: true
        triggeredOnStart: true

        onTriggered: pingProcess.running = true
    }

    Process {
        id: pingProcess

        command: ["timeout", "3", "ping", "-c", "1", "-W", "1", "omarchy.org"]

        stdout: StdioCollector {
            id: pingOutput
            waitForEnd: true
            onStreamFinished: metrics.applyPing(pingOutput.text)
        }

        onExited: function (exitCode, exitStatus) {
            if (exitCode !== 0) {
                metrics.pingMs = 0;
                metrics.pingMeasured = true;
            }
        }
    }

    Process {
        id: networkMountProcess

        // Two seconds is already generous for a healthy server; a dead mount
        // is killed before it can affect the disk tooltip.
        command: ["timeout", "2", "findmnt", "-rn", "-b", "-o", "TARGET,SOURCE,FSTYPE,SIZE,USED,AVAIL", "-t", "nfs,nfs4,cifs,smb3"]

        stdout: StdioCollector {
            id: networkMountOutput
            waitForEnd: true
            onStreamFinished: metrics.applyNetworkMounts(networkMountOutput.text)
        }

        onExited: function (exitCode, exitStatus) {
            if (exitCode !== 0) {
                // Timeout, no match or error: never keep a stale network row.
                metrics.networkMounts = [];
            }

            if (exitCode !== 0 && exitCode !== 1 && exitCode !== 124) {
                console.warn("yassm: network findmnt exited with", exitCode);
            }
        }
    }

    Process {
        id: temperatureProcess

        command: ["timeout", "5", "bash", metrics.temperatureScriptPath]

        stdout: StdioCollector {
            id: temperatureOutput
            waitForEnd: true
            onStreamFinished: metrics.applyTemperatures(temperatureOutput.text)
        }

        onExited: function (exitCode, exitStatus) {
            if (exitCode !== 0 && exitCode !== 124) {
                console.warn("yassm: temperature scan exited with", exitCode);
            }
        }
    }

    Process {
        id: depsProcess

        command: ["timeout", "5", "bash", metrics.depsScriptPath]

        stdout: StdioCollector {
            id: depsOutput
            waitForEnd: true
            onStreamFinished: metrics.applyDeps(depsOutput.text)
        }
    }

    Process {
        id: installDateProcess

        command: ["timeout", "5", "bash", metrics.installDateScriptPath]

        stdout: StdioCollector {
            id: installDateOutput
            waitForEnd: true
            onStreamFinished: metrics.applyInstallDate(installDateOutput.text)
        }
    }

    Process {
        id: ifaceIpProcess

        command: ["timeout", "3", "ip", "-4", "-o", "addr", "show", "dev", metrics.networkInterface]

        stdout: StdioCollector {
            id: ifaceIpOutput
            waitForEnd: true
            onStreamFinished: metrics.applyIfaceIp(ifaceIpOutput.text)
        }
    }

    Process {
        id: wanIpProcess

        command: ["timeout", "6", "curl", "-fsS", "--max-time", "5", "https://api.ipify.org"]

        stdout: StdioCollector {
            id: wanIpOutput
            waitForEnd: true
            onStreamFinished: metrics.applyWanIp(wanIpOutput.text)
        }
    }

    Process {
        id: wifiFreqProcess

        command: ["timeout", "5", "bash", metrics.wifiFreqScriptPath, metrics.networkInterface]

        stdout: StdioCollector {
            id: wifiFreqOutput
            waitForEnd: true
            onStreamFinished: metrics.applyWifiFreq(wifiFreqOutput.text)
        }
    }

    Timer {
        // Only shown in the NET tooltip: sample it while that tooltip is
        // open (roaming is the only thing that changes the frequency).
        interval: metrics.fastIntervalMs
        running: metrics.wifiDetailEnabled && metrics.activeWifi
        repeat: true
        triggeredOnStart: true

        onTriggered: wifiFreqProcess.running = true
    }

    Process {
        id: cpuFreqProcess

        command: ["timeout", "5", "bash", metrics.cpuFreqScriptPath]

        stdout: StdioCollector {
            id: cpuFreqOutput
            waitForEnd: true
            onStreamFinished: metrics.applyCpuFreq(cpuFreqOutput.text)
        }
    }

    Timer {
        // Per-core frequencies follow the fast loop while the CPU tooltip is
        // open; the script is only a few milliseconds.
        interval: metrics.fastIntervalMs
        running: metrics.cpuFreqEnabled
        repeat: true
        triggeredOnStart: true

        onTriggered: cpuFreqProcess.running = true
    }

    Process {
        id: alertsProcess

        command: ["timeout", "10", "bash", metrics.alertsScriptPath]

        stdout: StdioCollector {
            id: alertsOutput
            waitForEnd: true
            onStreamFinished: metrics.applyAlerts(alertsOutput.text)
        }
    }

    Timer {
        interval: metrics.alertsIntervalMs
        running: metrics.alertsEnabled
        repeat: true
        triggeredOnStart: true

        onTriggered: alertsProcess.running = true
    }

    // Same uplink, different network: the cached LAN and public addresses
    // belong to the previous Wi-Fi network, so drop them without waiting for
    // the five-minute TTL.
    onWifiSsidChanged: {
        if (!metrics.activeWifi) {
            return;
        }

        metrics.ifaceIpv4 = "";
        metrics.wanIp = "";
        metrics.wanIpUpdatedAt = 0;
        metrics.networkDetailsInvalidated();
    }

    Component.onCompleted: {
        installDateProcess.running = true;
        depsProcess.running = true;
    }
}
