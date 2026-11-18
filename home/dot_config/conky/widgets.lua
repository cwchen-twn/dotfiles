-- Helpers for the Conky windows (${lua NAME ARGS}): numbers Conky has no built-in for, read from sysfs and /proc
-- with no subprocesses. Same formulas as cpu-stat (battery draw) and mem-stat (memory in use, swap).

local function read(path)
    local f = io.open(path)
    if not f then return nil end
    local s = f:read('*l')
    f:close()
    return s
end

local function num(path) return tonumber(read(path) or '') end

-- hwmon directories by driver name (hwmonN numbering changes between boots)
local hwmon = {}
local function hwmon_dir(name)
    if hwmon[name] == nil then
        hwmon[name] = false
        for i = 0, 15 do
            local d = '/sys/class/hwmon/hwmon' .. i
            if read(d .. '/name') == name then hwmon[name] = d; break end
        end
    end
    return hwmon[name] or nil
end

-- ${lua temp coretemp Package} -> "48°C": the temp*_input whose label starts with LABEL (or temp1 without one)
function conky_temp(name, label)
    local d = hwmon_dir(name)
    if not d then return '' end
    for i = 1, 8 do
        local l = read(d .. '/temp' .. i .. '_label')
        if (label == nil and i == 1) or (l and label and l:sub(1, #label) == label) then
            local t = num(d .. '/temp' .. i .. '_input')
            return t and string.format('%d°C', t // 1000) or ''
        end
    end
    return ''
end

-- Memory in use = MemTotal - MemAvailable (buff/cache is handed back on demand), as mem-stat counts it.
local function meminfo()
    local m = {}
    for line in io.lines('/proc/meminfo') do
        local k, v = line:match('^(%w+):%s+(%d+)')
        if k then m[k] = tonumber(v) end
    end
    return m
end

function conky_mem_perc()
    local m = meminfo()
    return string.format('%d', (m.MemTotal - m.MemAvailable) * 100 // m.MemTotal)
end

function conky_mem_used()
    local m = meminfo()
    return string.format('%.1f / %.1f GB', (m.MemTotal - m.MemAvailable) / 1048576, m.MemTotal / 1048576)
end

function conky_mem_free()
    return string.format('%.1f GB free', meminfo().MemAvailable / 1048576)
end

-- ${lua swap zram} / ${lua swap disk} -> "12M / 3.8G": used / size of that kind of swap, from /proc/swaps
local function human(kb)
    if kb >= 1048576 then return string.format('%.1fG', kb / 1048576) end
    return string.format('%dM', kb // 1024)
end

function conky_swap(kind)
    local size, used, any = 0, 0, false
    for line in io.lines('/proc/swaps') do
        local dev, s, u = line:match('^(%S+)%s+%S+%s+(%d+)%s+(%d+)')
        if dev and ((dev:match('zram') and 'zram' or 'disk') == kind) then
            size, used, any = size + tonumber(s), used + tonumber(u), true
        end
    end
    return any and (human(used) .. ' / ' .. human(size)) or 'none'
end

-- GPU busy % (Intel i915): 100 minus the share of time in RC6, the GPU's idle state. No root needed, unlike
-- intel_gpu_top. Computed once per Conky update (the text and the bar both ask).
local card = '/sys/class/drm/card0'
local gpu = { rc6 = nil, t = nil, busy = 0, update = -1 }
function conky_gpu_busy()
    local u = tonumber(conky_parse('${updates}')) or 0
    if u ~= gpu.update then
        gpu.update = u
        local rc6 = num(card .. '/power/rc6_residency_ms')
        local t = tonumber((read('/proc/uptime') or ''):match('^[%d.]+'))
        if rc6 and t and gpu.rc6 and t > gpu.t then
            local idle = (rc6 - gpu.rc6) / ((t - gpu.t) * 1000)
            gpu.busy = math.max(0, math.min(100, (1 - idle) * 100))
        end
        gpu.rc6, gpu.t = rc6, t
    end
    return string.format('%d', math.floor(gpu.busy + 0.5))
end

function conky_gpu_freq()
    local act, max = num(card .. '/gt_act_freq_mhz'), num(card .. '/gt_max_freq_mhz')
    if not act then return '' end
    return string.format('%d/%d MHz', act, max or 0)
end

-- Battery: "−12.3 W" while discharging, "+30.1 W" while charging (voltage_now x current_now, in µV and µA)
local function bat_dir(bat) return '/sys/class/power_supply/' .. (bat or 'BAT0') end

function conky_bat_watts(bat)
    local d = bat_dir(bat)
    local p = num(d .. '/power_now')
    if not p then
        local v, i = num(d .. '/voltage_now'), num(d .. '/current_now')
        if not (v and i) then return '' end
        p = v * i / 1e6
    end
    local status = read(d .. '/status') or ''
    if status == 'Discharging' then return string.format('−%.1f W', p / 1e6) end
    if status == 'Charging' then return string.format('+%.1f W', p / 1e6) end
    return ''
end

function conky_bat_status(bat) return (read(bat_dir(bat) .. '/status') or ''):lower() end

-- "3h 30m": to empty while discharging, to full while charging (charge in µAh / current in µA)
function conky_bat_time(bat)
    local d = bat_dir(bat)
    local status, i = read(d .. '/status'), num(d .. '/current_now')
    local now, full = num(d .. '/charge_now'), num(d .. '/charge_full')
    if not (i and i > 0 and now) then return '' end
    local h
    if status == 'Discharging' then h = now / i
    elseif status == 'Charging' and full then h = (full - now) / i
    else return '' end
    local m = math.floor(h * 60 + 0.5)
    return string.format('%dh %02dm', m // 60, m % 60)
end

-- Top apps by CPU and by memory, processes summed per app (all of Brave is one line), like cpu-stat and mem-stat.
-- Conky's own ${top} rescans every process on every update (about 4% of a core here); this rescans every 10 s.
-- ${lua top cpu N} / ${lua top mem N} -> "name|value" for the Nth app; split by top_name / top_value below.
local HZ, PAGE_KB, EVERY = 100, 4, 10
local tops = { at = -EVERY, ticks = {}, cpu = {}, mem = {} }

local function uptime() return tonumber((read('/proc/uptime') or ''):match('^[%d.]+')) or 0 end

local function rescan()
    local now = uptime()
    if now - tops.at < EVERY then return end
    local dt = now - tops.at
    local ticks, cpu, mem = {}, {}, {}
    local p = io.popen('ls /proc')
    for pid in p:lines() do
        if pid:match('^%d+$') then
            local stat = read('/proc/' .. pid .. '/stat')
            local statm = read('/proc/' .. pid .. '/statm')
            if stat and statm then
                local name, rest = stat:match('%((.*)%)%s+(.*)')
                if name then
                    local f = {}
                    for x in rest:gmatch('%S+') do f[#f + 1] = x end
                    local t = tonumber(f[12]) + tonumber(f[13])      -- utime + stime (fields 14, 15)
                    ticks[pid] = t
                    if tops.ticks[pid] then cpu[name] = (cpu[name] or 0) + (t - tops.ticks[pid]) end
                    local rss = tonumber(statm:match('^%d+%s+(%d+)')) or 0
                    if rss > 0 then mem[name] = (mem[name] or 0) + rss * PAGE_KB end
                end
            end
        end
    end
    p:close()
    local function sorted(tbl, fmt)
        local list = {}
        for n, v in pairs(tbl) do if v > 0 then list[#list + 1] = { n, v } end end
        table.sort(list, function(a, b) return a[2] > b[2] end)
        for i, e in ipairs(list) do list[i] = { e[1], fmt(e[2]) } end
        return list
    end
    tops.cpu = sorted(cpu, function(v) return string.format('%.1f%%', v * 100 / (HZ * dt)) end)
    tops.mem = sorted(mem, function(v) return human(v) end)
    -- The first scan has nothing to compare CPU time against: take the second one after 2 s, not 10.
    tops.at = next(tops.ticks) and now or now - EVERY + 2
    tops.ticks = ticks
end

function conky_top_name(kind, i)
    rescan()
    local e = tops[kind][tonumber(i)]
    return e and e[1]:sub(1, 16) or ''
end

function conky_top_value(kind, i)
    rescan()
    local e = tops[kind][tonumber(i)]
    return e and e[2] or ''
end

-- ${lua net_watch SIG} (in the first Network title, returns nothing): SIG is the comma-separated list of connected
-- interfaces the window was built with ('-' for none). Reload the window (SIGUSR1: Conky re-reads its config and
-- layout.lua rebuilds the Network blocks) when the list now differs: one connected or dropped, or the traffic moved
-- to another one (the first is the one in use). Checked on every update; it only reads /proc and /sys.
local connected = dofile(os.getenv('HOME') .. '/.config/conky/net.lua')
function conky_net_watch(sig)
    local names = {}
    for _, n in ipairs(connected()) do names[#names + 1] = n.name end
    local now = #names > 0 and table.concat(names, ',') or '-'
    if now ~= (sig or '-') then
        local pid = (read('/proc/self/stat') or ''):match('^(%d+)')
        if pid then os.execute('kill -USR1 ' .. pid) end
    end
    return ''
end

-- ${lua_parse reboot_notice} (prefixed to the window's first line): a red "Reboot" title line when a newer kernel or
-- a library waits for one (reboot-needed in ~/.local/bin, the same check fish runs at shell start), else nothing.
-- Security updates install themselves daily, so this is checked every 5 minutes, not on every update.
local reboot = { at = -300, text = '' }
function conky_reboot_notice()
    local now = uptime()
    if now - reboot.at >= 300 then
        reboot.at = now
        local p = io.popen('"$HOME/.local/bin/reboot-needed" 2>/dev/null')
        local msg = p and p:read('*l') or ''
        if p then p:close() end
        local what = msg:match('kernel (%S+) installed')
        what = what and ('kernel ' .. what:gsub('[+-].*', '')) or (msg:match(': (%S+)') or ''):sub(1, 16)
        reboot.text = msg ~= '' and ('${font1}${color f38ba8}Reboot${font}${alignr}' .. what .. ' waiting${color}\n${voffset 8}') or ''
    end
    return reboot.text
end
