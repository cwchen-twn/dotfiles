function mem-stat --description 'Memory at a glance: summary, swap (zram vs disk) and the top apps (processes summed per app): mem-stat [N]'
    set -l top 12
    if set -q argv[1]
        if not string match -qr '^[0-9]+$' -- $argv[1]
            echo "usage: mem-stat [N]   (N apps, default 12)" >&2
            return 2
        end
        set top $argv[1]
    end

    # "available" is what matters: buff/cache is handed back the moment an app needs it.
    free -h
    awk '/^MemTotal/ {t=$2} /^MemAvailable/ {a=$2}
         END {printf "\nIn use %.1f GB of %.1f GB (%d%%), available %.1f GB\n", (t-a)/1048576, t/1048576, (t-a)*100/t, a/1048576}' /proc/meminfo

    echo
    echo Swap
    awk 'NR > 1 {printf "  %-16s %6.0f MB used of %6.0f MB (priority %s)\n", $1, $4/1024, $3/1024, $5}' /proc/swaps
    # zram mm_stat: orig_data_size compr_data_size ... (bytes); only meaningful once something was swapped
    if test -r /sys/block/zram0/mm_stat
        read -l orig compr _rest </sys/block/zram0/mm_stat
        if test "$orig" -gt 1048576
            printf '  zram holds %.0f MB of pages in %.0f MB (%.1fx)\n' (math $orig / 1048576) (math $compr / 1048576) (math $orig / $compr)
        end
    end

    echo
    echo "Top $top apps (resident memory, processes summed per app)"
    ps -eo rss=,comm= | awk '{a[$2] += $1} END {for (k in a) printf "%8.0f MB  %s\n", a[k]/1024, k}' | sort -rn | head -n $top

    # earlyoom kills today (the system journal is only readable for the adm / systemd-journal groups)
    set -l kills (journalctl -u earlyoom --since today --no-pager -q 2>/dev/null | string match -e 'sending SIG')
    if test (count $kills) -gt 0
        echo
        echo "earlyoom killed $(count $kills) process(es) today; last: $kills[-1]"
    end
end
