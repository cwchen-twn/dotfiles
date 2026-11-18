-- Connected network interfaces, shared by layout.lua (one Network block each) and widgets.lua (net_watch: restart
-- the window when this list changes). Returns a list of { name, wifi, primary }, the primary first.
-- Connected: a physical interface (it has a device: no lo, tailscale0, docker0, VPN tunnels) whose operstate is
-- "up" (Wi-Fi associated, Ethernet cable in). Primary: the one carrying the default route with the lowest metric,
-- the one Linux sends traffic through (NetworkManager: Ethernet 100, Wi-Fi 600, a second device of a kind +1).
-- Reads /proc and /sys only, no subprocesses: net_watch runs it on every update.

local function read(path)
    local f = io.open(path)
    if not f then return nil end
    local s = f:read('*l')
    f:close()
    return s
end

return function()
    local primary, best
    for line in io.lines('/proc/net/route') do
        local i, dest, metric = line:match('^(%S+)%s+(%x+)%s+%x+%s+%x+%s+%d+%s+%d+%s+(%d+)')
        if dest == '00000000' and (not best or tonumber(metric) < best) then primary, best = i, tonumber(metric) end
    end
    local list = {}
    for line in io.lines('/proc/net/dev') do
        local i = line:match('^%s*([^%s:]+):')
        local sys = i and '/sys/class/net/' .. i
        if i and read(sys .. '/device/uevent') and read(sys .. '/operstate') == 'up' then
            list[#list + 1] = { name = i, wifi = read(sys .. '/phy80211/name') ~= nil, primary = i == primary }
        end
    end
    table.sort(list, function(a, b)
        if a.primary ~= b.primary then return a.primary end
        return a.name < b.name
    end)
    return list
end
