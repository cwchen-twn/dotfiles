function bt-pair --description 'Classic Bluetooth: `bt-pair` lists nearby devices; `bt-pair N|NAME|ADDR` pairs, trusts, connects and switches the sound to it'
    # Classic (BR/EDR) scan only: in a crowded place LE adverts from TVs, beacons and the "LE_<name>" Fast Pair entry
    # of many headphones flood a normal scan (and blueman's window burns CPU on each one). The scan collects the
    # addresses it hears -- a device bluez already knows only reports RSSI changes, never its name again -- and the
    # names come from bluez afterwards. `bt-pair` remembers the list, so `bt-pair 2` picks its second row.
    set -l secs 12
    set -l strip 's/\x1b\[[0-9;]*m//g'
    set -l list $HOME/.cache/bt-devices.tsv
    set -l target $argv[1]

    bluetoothctl power on >/dev/null
    set -l addr
    if string match -qr '^[0-9]+$' -- "$target"
        set addr (sed -n "$target"p $list 2>/dev/null | string split -f1 \t)
        if test -z "$addr"
            echo "bt-pair: no device #$target; run bt-pair first" >&2
            return 1
        end
    else if string match -qr '^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$' -- "$target"
        set addr (string upper -- $target)
    else
        echo "Scanning classic Bluetooth for $secs s (put the device in pairing mode first)…"
        set -l heard (timeout (math $secs + 5) stdbuf -oL bluetoothctl --timeout $secs scan bredr 2>/dev/null \
            | sed -u $strip | string match -rg 'Device ([0-9A-F:]{17})' | sort -u)
        bluetoothctl scan off >/dev/null 2>&1
        # address \t name \t icon \t flags, for every device heard in this scan
        mkdir -p (path dirname $list)
        printf '' >$list
        for a in $heard
            set -l info (bluetoothctl info $a 2>/dev/null)
            set -l n (string match -rg '^\s*Name: (.*)$' -- $info)[1]
            test -z "$n"; and set n '(no name)'
            set -l icon (string match -rg '^\s*Icon: (.*)$' -- $info)[1]
            set -l flags
            string match -q '*Paired: yes*' -- $info; and set -a flags paired
            string match -q '*Connected: yes*' -- $info; and set -a flags connected
            printf '%s\t%s\t%s\t%s\n' $a "$n" "$icon" "$flags" >>$list
        end
        sort -t \t -k2,2f -o $list $list

        if test -z "$target"
            if not test -s $list
                echo "No classic Bluetooth devices heard. Headphones must be in pairing mode, not just on." >&2
                return 1
            end
            printf '%-3s %-28s %-18s %-18s %s\n' '#' Name Address Type State
            set -l i 0
            for line in (cat $list)
                set i (math $i + 1)
                set -l f (string split \t -- $line)
                printf '%-3s %-28s %-18s %-18s %s\n' $i (string shorten -m 28 -- $f[2]) $f[1] $f[3] $f[4]
            end
            echo
            echo "Pair one: bt-pair N   (or bt-pair NAME / ADDRESS)"
            return 0
        end
        set addr (string match -r '^\S+\t'(string escape --style=regex -- $target)'\t' <$list | string split -f1 \t)[1]
        if test -z "$addr"
            echo "'$target' not heard. In pairing mode? Phones it knows may grab it first: turn their Bluetooth off." >&2
            echo "Run bt-pair without a name to see what is around." >&2
            return 1
        end
    end
    set -l name (bluetoothctl info $addr 2>/dev/null | string match -rg '^\s*Name: (.*)$')[1]
    echo "Pairing $name ($addr)"

    if not bluetoothctl info $addr | string match -q '*Paired: yes*'
        bluetoothctl --timeout 25 pair $addr | string match -e -r 'Pairing successful|Failed|Error'
    end
    bluetoothctl trust $addr >/dev/null
    bluetoothctl --timeout 15 connect $addr | string match -e -r 'Connection successful|Failed|Error'

    # Audio devices: make them the default output and move what is playing now.
    set -l sink
    for i in (seq 10)
        set sink (pactl list short sinks | string match -rg '^\d+\s+(bluez_sink\.'(string replace -a : _ $addr)'\S*)')[1]
        test -n "$sink"; and break
        sleep 1
    end
    if test -n "$sink"
        pactl set-default-sink $sink
        for input in (pactl list short sink-inputs | string match -rg '^(\d+)')
            pactl move-sink-input $input $sink
        end
        echo "Sound now goes to $sink"
    else if bluetoothctl info $addr | string match -q '*Connected: yes*'
        echo "Connected (not an audio output)."
    end
end
