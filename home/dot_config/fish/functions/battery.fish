function battery --description 'Battery at a glance: `battery` status, health and charge cap; `battery full` charges to 100% once; `battery limit [N]` caps it again; `battery info` (upower), `battery tlp` (sudo tlp-stat -b)'
    # The cap is the SMC key BCLM (MacBooks: applesmc-bclm, ansible macbook role): the SMC stops charging there. The boot unit
    # battery-charge-limit.service sets it back to the default, so `battery full` lasts until the next boot.
    set -l bats /sys/class/power_supply/BAT* # set allows an empty glob
    if test (count $bats) -eq 0
        echo "battery: no battery" >&2
        return 1
    end
    set -l bat $bats[1]
    set -l cap /sys/devices/platform/applesmc.768/charge_limit
    set -l setcap /usr/local/sbin/battery-charge-limit # sbin isn't on a normal user's PATH

    switch "$argv[1]"
        case full limit
            if not test -e $cap; or not test -x $setcap
                echo "battery: no charge cap on this machine (applesmc-bclm, ansible macbook role)" >&2
                return 1
            end
            if test $argv[1] = full
                sudo $setcap 100; or return
                echo "Charging to 100% until the next boot or `battery limit`."
            else
                sudo $setcap $argv[2]; or return
                echo "Charging stops at $(cat $cap)%."
            end
        case info
            if not command -q upower
                echo "battery: upower is not installed" >&2
                return 1
            end
            upower -i (upower -e | string match '*BAT*')
        case tlp
            if not command -q tlp-stat
                echo "battery: TLP is not installed" >&2
                return 1
            end
            sudo tlp-stat -b
        case ''
            set -l status_ (cat $bat/status)
            set -l line "$(cat $bat/capacity)%  $status_"
            if test -r $cap
                set line "$line, charging stops at $(cat $cap)%"
            end
            echo $line

            # charge_* (µAh) on MacBooks, energy_* (µWh) elsewhere
            set -l full (cat $bat/charge_full $bat/energy_full 2>/dev/null)
            set -l design (cat $bat/charge_full_design $bat/energy_full_design 2>/dev/null)
            if test -n "$full[1]" -a -n "$design[1]"
                printf 'Health %d%% of design' (math -s0 "$full[1] * 100 / $design[1]")
                test -r $bat/cycle_count; and printf ', %s cycles' (cat $bat/cycle_count)
                echo
            end

            # temp is in tenths of a degree; power from current x voltage when power_now is missing
            set -l parts
            test -r $bat/temp; and set -a parts (printf '%.1f °C' (math (cat $bat/temp) / 10))
            set -l watts
            if test -r $bat/power_now
                set watts (math -s1 (cat $bat/power_now) / 1000000)
            else if test -r $bat/current_now -a -r $bat/voltage_now
                set watts (math -s1 "abs($(cat $bat/current_now)) * $(cat $bat/voltage_now) / 1000000000000")
            end
            test -n "$watts"; and set -a parts "$watts W"
            if command -q upower
                set -l eta (upower -i (upower -e | string match '*BAT*') | string match -rg '^\s*time to (?:empty|full):\s*(.+)')
                test -n "$eta"; and set -a parts "$eta to "(string match -q Charging $status_; and echo full; or echo empty)
            end
            test (count $parts) -gt 0; and string join '  ' $parts
        case '*'
            echo "usage: battery [full | limit [N] | info | tlp]" >&2
            return 2
    end
end
