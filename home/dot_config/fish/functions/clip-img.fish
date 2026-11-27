# Managed by chezmoi. Copy an image file to the clipboard as an image, to paste with Ctrl+V into apps that take
# pictures (Claude Code, chats) when dragging the file isn't handy. Screenshots are already copied this way
# (~/.local/bin/screenshot).
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
    wl-copy --type $type <"$file"
    and echo "copied $type: paste with Ctrl+V"
end
