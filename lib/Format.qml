pragma Singleton

import QtQuick

// Pure formatting helpers shared by the bar widget and its tooltip builders:
// sizes, rates, durations and a few string utilities. Nothing here reads the
// widget state, so it can be unit-checked on its own.
QtObject {

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
            return "0.00 KiB";
        }

        if (value >= 1073741824) {
            return (value / 1073741824).toFixed(2) + " TiB";
        }

        if (value >= 1048576) {
            return (value / 1048576).toFixed(2) + " GiB";
        }

        if (value >= 1024) {
            return (value / 1024).toFixed(2) + " MiB";
        }

        return value.toFixed(2) + " KiB";
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

    function formatRateField(kib) {
        const text = formatRateLong(kib);
        const space = text.indexOf(" ");

        return (text.slice(0, space).padStart(6, " ") + " " + text.slice(space + 1)).padEnd(12, " ");
    }

    function formatSessionField(kib) {
        const text = formatKibAsSize(kib);
        const space = text.indexOf(" ");

        return text.slice(0, space).padStart(7, " ") + " " + text.slice(space + 1).padEnd(3, " ");
    }

    function countryFlag(code) {
        const value = String(code || "").toUpperCase();

        if (!/^[A-Z]{2}$/.test(value)) {
            return "";
        }

        return String.fromCodePoint(0x1F1E6 + value.charCodeAt(0) - 65, 0x1F1E6 + value.charCodeAt(1) - 65);
    }

    function cleanSensorName(name) {
        const original = String(name || "").trim();
        const stripped = original.replace(/[\s_\-.]+(temperatures?|temps?)$/i, "").replace(/^(temperatures?|temps?)[\s_\-.]+/i, "").trim();

        return stripped === "" || /^[0-9]+$/.test(stripped) ? original : stripped;
    }

    function snapSwapKb(kilobytes) {
        const value = Number(kilobytes);

        return Number.isFinite(value) && value >= 1024 ? value : 0;
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

    function pad(value) {
        if (value === null || value === undefined) {
            return " --";
        }

        return String(value).padStart(3, " ");
    }
}
