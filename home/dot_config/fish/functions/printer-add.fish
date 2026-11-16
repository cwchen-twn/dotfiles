function printer-add --description 'Add printer N from `printers` (driverless IPP Everywhere): printer-add N [--default]'
    argparse d/default -- $argv; or return
    set -l list $HOME/.cache/printers.tsv
    if test (count $argv) -ne 1; or not string match -qr '^[0-9]+$' -- $argv[1]
        echo "usage: printer-add N [--default]   (N from the printers list)" >&2
        return 2
    end
    test -s $list; or printers >/dev/null
    set -l line (sed -n "$argv[1]p" $list)
    if test -z "$line"
        echo "printer-add: no printer #$argv[1]; run printers" >&2
        return 1
    end
    set -l f (string split \t -- $line)
    # queue name from the model, e.g. HP_Color_LaserJet_MFP_M281fdw; the .local host name keeps working when the
    # printer's IP changes (DHCP)
    set -l name (string replace -ra '[^A-Za-z0-9]+' _ -- (string replace -r '\s*[\[(].*$' '' -- $f[1]) | string trim -c _)
    set -l uri ipp://$f[3]:$f[4]/$f[5]
    echo "Adding $name -> $uri"
    # members of lpadmin manage CUPS without sudo; -m everywhere asks the printer for its capabilities (no driver)
    /usr/sbin/lpadmin -p $name -D "$f[1]" -E -v $uri -m everywhere -o printer-is-shared=false
    or sudo /usr/sbin/lpadmin -p $name -D "$f[1]" -E -v $uri -m everywhere -o printer-is-shared=false
    or return 1
    if set -q _flag_default
        /usr/sbin/lpadmin -d $name; or sudo /usr/sbin/lpadmin -d $name
    end
    lpstat -p $name
    echo "Print from any app's print dialog, or: lp -d $name FILE   (remove: /usr/sbin/lpadmin -x $name)"
end
