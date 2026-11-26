function yt --description 'Play a YouTube (or any yt-dlp) URL in mpv, GPU-decoded H.264: yt [URL]; no URL = the clipboard'
    set -l url $argv[1]
    if test -z "$url"; and command -q wl-paste
        set url (wl-paste --no-newline 2>/dev/null)
    end
    if not string match -qr '^https?://' -- "$url"
        echo "usage: yt URL   (or copy a link and run yt)" >&2
        return 2
    end
    # detached, so the terminal stays free; mpv's own window has the controls (space, arrows, f, q)
    setsid -f mpv --force-window=immediate -- $url >/dev/null 2>&1
end
