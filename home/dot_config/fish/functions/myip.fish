# Managed by chezmoi. Public IPv4/IPv6 (asked from OpenDNS over DNS, HTTPS as fallback) and local addresses.
function myip --description "Show public IPv4/IPv6 and local addresses"
    set -l v4 (dig +short +time=2 +tries=1 -4 myip.opendns.com A @resolver1.opendns.com 2>/dev/null)
    test -n "$v4"; or set v4 (curl -s4 --max-time 3 https://ifconfig.co 2>/dev/null)
    set -l v6 (dig +short +time=2 +tries=1 -6 myip.opendns.com AAAA @resolver1.ipv6-sandbox.opendns.com 2>/dev/null)
    test -n "$v6"; or set v6 (curl -s6 --max-time 3 https://ifconfig.co 2>/dev/null)
    echo "public IPv4: "(test -n "$v4"; and echo $v4; or echo none)
    echo "public IPv6: "(test -n "$v6"; and echo $v6; or echo none)
    echo "local:"
    if command -q ip
        ip -br addr show | string match -rv '^lo\s' | string replace -r '^' '  '
    else
        ifconfig | awk '/^[a-z]/ {i=$1} /inet6? / && $2 !~ /^(127|::1|fe80)/ {print "  " i " " $2}'
    end
end
