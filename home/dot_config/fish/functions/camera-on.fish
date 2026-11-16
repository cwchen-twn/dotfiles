# Managed by chezmoi. Start the camera relay (/dev/video10, "FaceTime HD (relay)") for apps that don't see the camera.
function camera-on --description "Relay the FaceTime camera to /dev/video10"
    systemctl --user start camera-relay.service; and echo "camera relay on: pick 'FaceTime HD (relay)' in the app (camera-off to stop)"
end
