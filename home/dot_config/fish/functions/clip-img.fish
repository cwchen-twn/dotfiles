# Managed by chezmoi. Copy an image file to the clipboard as an image, to paste with Ctrl+V into apps that take
# pictures (Claude Code, chats). The Wayland session's alacritty can't take a file by drag-and-drop (winit), and
# Print / Shift+Print already copy screenshots this way (~/.local/bin/screenshot).
function clip-img --description "Copy an image file to the clipboard: clip-img FILE"
    set -l file $argv[1]
    if not test -f "$file"
        echo "usage: clip-img FILE" >&2
        return 2
    end
    set -l type (file --brief --mime-type -- "$file")
    if not string match -q 'image/*' -- $type
        echo "clip-img: $file is $type, not an image" >&2
        return 1
    end
    if set -q WAYLAND_DISPLAY; and command -q wl-copy
        wl-copy --type $type <"$file"
    else if command -q xclip
        xclip -selection clipboard -target $type -i "$file"
    else
        echo "clip-img: needs wl-copy (Wayland) or xclip (X11)" >&2
        return 1
    end
    and echo "copied $type: paste with Ctrl+V"
end
