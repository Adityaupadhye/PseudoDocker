cleanup_previous() {
    echo "Cleaning up previous runs..."
    sudo ./conductor.sh stop cs-cont
    sudo ./conductor.sh stop es-cont
    sudo ./conductor.sh rmi es-image
    sudo ./conductor.sh rmi cs-image

    sudo umount -l .containers/*/merged 2> /dev/null
    sudo umount -l .cache/layers/*/merged 2> /dev/null
    sudo rm -f /var/run/netns/*
    sudo rm -rf .cache .containers .images
}
cleanup_previous