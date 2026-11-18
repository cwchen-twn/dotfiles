# Interactive shells say when a new kernel or library waits for a reboot (security updates install themselves but
# never reboot). Silent otherwise. ~/.local/bin/reboot-needed does the check.
status is-interactive; or return
command -q reboot-needed; or return
set -l msg (reboot-needed); and set_color yellow; and echo $msg; and set_color normal
