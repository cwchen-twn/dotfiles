-- Shared by left.conf and right.conf: the window settings and the sections, so the two Conky windows look alike.
-- The screen is split in 4 columns: left.conf fills the first (disk, network, GPU, battery), right.conf the last
-- (CPU, memory); the two in the middle stay clear. Each window sits under all other windows.
-- Catppuccin Mocha colors, light shades only: the wallpaper is dark navy. Sections for hardware a machine lacks
-- (battery, Wi-Fi, Intel GPU) are left out. Helpers: widgets.lua. Terminal versions: cpu-stat, mem-stat.

local home = os.getenv('HOME')

local function read(path)
    local f = io.open(path)
    if not f then return nil end
    local s = f:read('*l')
    f:close()
    return s
end

-- Sizes are pixels at 96 dpi: Conky scales them by Xft.dpi itself (2x on Retina). Fonts are in points, which
-- Xft scales by the same dpi (a font pixelsize would not be scaled).
-- Conky's gap_x/gap_y reach the text, not the window edge: the inner margin and 2 px of border are taken off them.
local edge, margin = 24, 14             -- screen edge to window, window edge to text
local gap = edge + margin + 2
local W = 264   -- content width; replaced below so the window plus `edge` is a quarter of the primary monitor
local dpi = 96
do
    local p = io.popen('xrandr --listactivemonitors 2>/dev/null; xrdb -get Xft.dpi 2>/dev/null')
    if p then
        local out = p:read('*a'); p:close()
        dpi = tonumber(out:match('\n(%d+)%s*$') or '') or 96
        local sw = tonumber(out:match('%+%*%S+%s+(%d+)/') or out:match('%s(%d+)/%d+x') or '')
        if sw then W = math.floor(sw / 4 / (dpi / 96)) - edge - 2 * margin - 4 end
    end
end
local graph = 32
local barh = 8

-- Hardware, found once at start: the disk holding /, the interface of the default route, the battery, the GPU.
local disk
do
    local p = io.popen('lsblk -no PKNAME "$(findmnt -no SOURCE /)" 2>/dev/null')
    if p then disk = p:read('*l'); p:close() end
    if disk == '' then disk = nil end
end
local iface
for line in io.lines('/proc/net/route') do
    local i, dest = line:match('^(%S+)%s+(%x+)')
    if dest == '00000000' then iface = i; break end
end
local wifi = false
for line in io.lines('/proc/net/wireless') do
    if iface and line:match('^%s*' .. iface:gsub('%p', '%%%0') .. ':') then wifi = true end
end
local bat
for _, b in ipairs({ 'BAT0', 'BAT1', 'BAT' }) do
    if read('/sys/class/power_supply/' .. b .. '/type') == 'Battery' then bat = b; break end
end
local gpu = read('/sys/class/drm/card0/power/rc6_residency_ms') ~= nil
local cores = 0
for line in io.lines('/proc/cpuinfo') do
    if line:match('^processor') then cores = cores + 1 end
end

-- Sections: each appends its lines to t.
local t = {}
local function add(line) t[#t + 1] = line end
local function title(name, right)
    add((#t > 0 and '${voffset 8}' or '') .. '${font1}${color1}' .. name .. '${font}${color}' .. (right and ('${alignr}' .. right) or ''))
end
local half = (W - 8) // 2
local col2 = half + 8
local function bar(expr) add('${voffset 2}' .. expr) end

local sections = {}

function sections.cpu()
    title('CPU', '${cpu cpu0}%  ${freq_g} GHz  ${lua temp coretemp Package}')
    add('${cpugraph cpu0 ' .. graph .. ',' .. W .. ' 89b4fa a6e3a1 -t}')
    for c = 1, cores do
        add('${color2}' .. (c - 1) .. '${color}${goto 30}${cpubar cpu' .. c .. ' ' .. barh .. ',' .. (W - 30 - 56)
            .. '}${alignr}${cpu cpu' .. c .. '}%')
    end
    for i = 1, 5 do
        add('${color2}${lua top_name cpu ' .. i .. '}${alignr}${lua top_value cpu ' .. i .. '}${color}')
    end
end

function sections.mem()
    title('Memory', '${lua mem_perc}%')
    bar('${lua_bar ' .. barh .. ',' .. W .. ' mem_perc}')
    add('${lua mem_used}${alignr}${lua mem_free}')
    add('${color2}zram${color}${alignr}${lua swap zram}')
    add('${color2}disk swap${color}${alignr}${lua swap disk}')
    for i = 1, 5 do
        add('${color2}${lua top_name mem ' .. i .. '}${alignr}${lua top_value mem ' .. i .. '}${color}')
    end
end

function sections.disk()
    if not disk then return end
    title('Disk', disk .. (disk:match('^nvme') and '  ${lua temp nvme Composite}' or ''))
    add('${color2}read${color} ${diskio_read ' .. disk .. '}${goto ' .. col2 .. '}${color2}write${color} ${diskio_write ' .. disk .. '}')
    add('${diskiograph_read ' .. disk .. ' ' .. graph .. ',' .. half .. ' 89b4fa a6e3a1 -t}'
        .. '${goto ' .. col2 .. '}${diskiograph_write ' .. disk .. ' ' .. graph .. ',' .. half .. ' fab387 f38ba8 -t}')
    add('${color2}/${color} ${fs_used /} of ${fs_size /}${alignr}${fs_used_perc /}%')
end

function sections.net()
    if not iface then return end
    title('Network', wifi and ('Wi-Fi  ${wireless_link_qual_perc ' .. iface .. '}%') or iface)
    add('${color2}down${color} ${downspeed ' .. iface .. '}${goto ' .. col2 .. '}${color2}up${color} ${upspeed ' .. iface .. '}')
    add('${downspeedgraph ' .. iface .. ' ' .. graph .. ',' .. half .. ' 89b4fa a6e3a1 -t}'
        .. '${goto ' .. col2 .. '}${upspeedgraph ' .. iface .. ' ' .. graph .. ',' .. half .. ' fab387 f38ba8 -t}')
end

function sections.gpu()
    if not gpu then return end
    title('GPU', '${lua gpu_busy}%  ${lua gpu_freq}')
    bar('${lua_bar ' .. barh .. ',' .. W .. ' gpu_busy}')
end

function sections.bat()
    if not bat then return end
    title('Battery', '${battery_percent ' .. bat .. '}%  ${lua bat_watts ' .. bat .. '}')
    bar('${battery_bar ' .. barh .. ',' .. W .. ' ' .. bat .. '}')
    add('${color2}${lua bat_status ' .. bat .. '}${color}${alignr}${lua bat_time ' .. bat .. '}')
end

-- left.conf / right.conf: build('top_left', {'disk', 'net', ...})
return function(alignment, names)
    conky.config = {
        -- A normal window kept below everything: pcmanfm-qt's desktop is itself a window, so a 'desktop'-type
        -- Conky would be drawn under it. Real transparency comes from xfwm4's compositor (ARGB visual).
        own_window = true,
        own_window_type = 'normal',
        own_window_hints = 'undecorated,below,sticky,skip_taskbar,skip_pager',
        own_window_class = 'Conky',
        own_window_title = 'conky-' .. alignment,
        own_window_argb_visual = true,
        own_window_argb_value = 179,     -- 70% dark backing: mutes the wallpaper's stars behind the text
        own_window_colour = '11111b',    -- crust
        double_buffer = true,

        alignment = alignment,
        gap_x = gap,
        gap_y = gap,
        minimum_width = W,
        maximum_width = W,
        border_inner_margin = margin,
        draw_borders = false,
        draw_outline = false,
        draw_shades = false,
        draw_graph_borders = false,

        update_interval = 2,
        cpu_avg_samples = 2,
        net_avg_samples = 2,
        diskio_avg_samples = 2,
        no_buffers = true,
        short_units = true,
        format_human_readable = true,
        if_up_strictness = 'address',

        use_xft = true,
        font = 'JetBrains Mono:size=12',          -- 16 px at 96 dpi
        font1 = 'JetBrains Mono:bold:size=12',
        default_color = 'cdd6f4',        -- text: values
        color1 = '89b4fa',               -- blue: section titles
        color2 = 'a6adc8',               -- subtext0: labels, process names
        default_bar_width = W,
        default_bar_height = barh,
        default_graph_width = W,
        default_graph_height = graph,
        lua_load = home .. '/.config/conky/widgets.lua',
    }
    for _, n in ipairs(names) do sections[n]() end
    conky.text = table.concat(t, '\n')
end
