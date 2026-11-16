# Managed by chezmoi. Listening TCP/UDP sockets with their processes.
function ports --description "List listening ports and their processes"
    if command -q ss
        sudo ss -tulpn $argv
    else
        sudo lsof -iTCP -sTCP:LISTEN -n -P $argv
    end
end
