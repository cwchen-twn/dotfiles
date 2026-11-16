# Managed by chezmoi. Stop the camera relay started by camera-on.
function camera-off --description "Stop the FaceTime camera relay"
    systemctl --user stop camera-relay.service; and echo "camera relay off"
end
