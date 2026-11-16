function printer-rm --description 'Remove a printer queue: printer-rm N (from `printers`) | QUEUE; no argument lists the queues'
    set -l queues (lpstat -v 2>/dev/null | string replace -rf '^device for ([^:]+): (.*)$' '$1\t$2')
    if test (count $argv) -ne 1
        echo "usage: printer-rm N|QUEUE   (N from the printers list)" >&2
        test (count $queues) -gt 0; and printf '  %s\n' (string replace \t '  ->  ' -- $queues) >&2
        return 2
    end
    set -l name $argv[1]
    if string match -qr '^[0-9]+$' -- $name
        # N from `printers`: the queue added for that printer's host
        set -l line (sed -n "$name"p $HOME/.cache/printers.tsv 2>/dev/null)
        if test -z "$line"
            echo "printer-rm: no printer #$name; run printers" >&2
            return 1
        end
        set -l host (string split \t -- $line)[3]
        set name (string match "*$host*" -- $queues | string split -f1 \t)
        if test -z "$name"
            echo "printer-rm: #$argv[1] ($host) has no queue" >&2
            return 1
        end
    end
    for q in $name
        if not contains -- $q (string split -f1 \t -- $queues)
            echo "printer-rm: no queue named $q (lpstat -v lists them)" >&2
            return 1
        end
        /usr/sbin/lpadmin -x $q; or sudo /usr/sbin/lpadmin -x $q; or return 1
        echo "removed $q"
    end
end
