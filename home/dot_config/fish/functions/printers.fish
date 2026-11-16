function printers --description 'Find printers on this network (IPP/AirPrint, driverless) and what they support; add one with printer-add N'
    if not command -q avahi-browse
        echo "printers: avahi-browse missing (apt install avahi-utils)" >&2
        return 1
    end
    set -l list $HOME/.cache/printers.tsv
    mkdir -p (path dirname $list)
    # -p parsable, -r resolve, -t stop after the first dump, -k raw service types; one row per printer host
    avahi-browse -rptk _ipp._tcp 2>/dev/null | awk -F';' '
        function unescape(s,   out, d) {
            out = ""; bs = sprintf("%c", 92)   # a backslash (fish quoting eats \\ in this script)
            while (match(s, bs bs "[0-9][0-9][0-9]")) {
                d = substr(s, RSTART + 1, 3) + 0
                out = out substr(s, 1, RSTART - 1) sprintf("%c", d)
                s = substr(s, RSTART + 4)
            }
            return out s
        }
        $1 == "=" && !seen[$7]++ {
            txt = $10; gsub(/^"|"$/, "", txt); n = split(txt, kv, /" "/)
            delete t
            for (i = 1; i <= n; i++) { p = index(kv[i], "="); if (p) t[substr(kv[i], 1, p - 1)] = substr(kv[i], p + 1) }
            yn["T"] = "yes"; yn["F"] = "no"
            printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", unescape($4), t["ty"], $7, $9, (t["rp"] ? t["rp"] : "ipp/print"),
                (t["Color"] in yn ? yn[t["Color"]] : "?"), (t["Duplex"] in yn ? yn[t["Duplex"]] : "?"),
                (t["Scan"] in yn ? yn[t["Scan"]] : "?"), $8
        }' >$list

    if not test -s $list
        echo "No printers found on this network (they must advertise IPP/AirPrint; check you're on the same LAN/Wi-Fi)."
        return 1
    end
    set -l queues (lpstat -v 2>/dev/null)
    printf '%-3s %-46s %-24s %-6s %-6s %-5s %s\n' '#' Printer Host Color Duplex Scan Added
    set -l i 0
    for line in (cat $list)
        set i (math $i + 1)
        set -l f (string split \t -- $line)
        set -l added -
        string match -q "*$f[3]*" -- $queues; and set added (string match -r '^device for ([^:]+)' -- (string match "*$f[3]*" -- $queues))[2]
        printf '%-3s %-46s %-24s %-6s %-6s %-5s %s\n' $i (string shorten -m 46 -- $f[1]) $f[3] $f[6] $f[7] $f[8] $added
    end
    echo
    echo "Add one: printer-add N [--default]   Then print from any app, or: lp -d QUEUE FILE"
    echo "Scanners on the same devices: simple-scan (or scanimage -L)"
end
