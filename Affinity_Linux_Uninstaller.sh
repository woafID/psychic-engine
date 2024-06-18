#!/usr/bin/env bash

trap '
    echo "Removal of Linux Affinity has been cancelled."
    exit 0
' SIGINT

# Root check
if [ "$EUID" -eq 0 ]; then
    echo "Please run as regular user."
    exit 1
fi

echo "Are you sure you want to remove Linux Affinity and all of its related files? (Y/N)"
read -r response

if [[ $response =~ ^[Yy]$ ]]; then
    rm -fr $HOME/affinity_setup_tmp
    rm -fr $HOME/LinuxCreativeSoftware/Affinity
    rmdir $HOME/LinuxCreativeSoftware --ignore-fail-on-non-empty
    rm -f $HOME/.local/share/applications/affinity_designer.desktop
    rm -f $HOME/.local/share/applications/affinity_photo.desktop
    rm -f $HOME/.local/share/applications/affinity_publisher.desktop
    echo
    echo "Elevation is required to remove the following:"
    echo "/usr/local/bin/rum" 
    echo "/opt/wines"
    echo
    
    sudo rm -f /usr/local/bin/rum
    sudo rm -fr /opt/wines
    echo Removal of Linux Affinity has finished.
else
    echo "Removal of Linux Affinity has been cancelled."
fi
