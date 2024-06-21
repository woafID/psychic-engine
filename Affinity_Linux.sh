#!/usr/bin/env bash

# Code functionality is commented to help everybody, including Linux beginners to better understand what is being run on their system.

# Functionality to clean up if the user presses Ctrl+C to abort the installation. This prevents users from having an incomplete/broken setup.
trap '
    echo "Operation interrupted... Cleaning up..."

    # Remove temporary setup files
    rm -fr $HOME/affinity_setup_tmp

    # Remove Affinity-related files and directories
    rm -fr $HOME/LinuxCreativeSoftware/Affinity
    rm $HOME/.local/share/applications/affinity_designer.desktop
    rm $HOME/.local/share/applications/affinity_photo.desktop
    rm $HOME/.local/share/applications/affinity_publisher.desktop

    # Remove the rum command
    echo Due to insufficient permissions, please remove the following files manually:
    echo /usr/local/bin/rum
    echo /opt/wines

    exit 0
' SIGINT

# Check if the script is being run with sudo, and if so, exit.
if [ "$EUID" -eq 0 ]; then
    echo "Please run as regular user."
    exit 1
fi

# If users launch with --uninstall, revert all modifications.
if [ "$1" = "--uninstall" ]; then
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
    exit 0
  else
    echo "Removal of Linux Affinity has been cancelled."
    exit 0
  fi
fi


# An animated loading spinner, which is later invoked by the   spinner "Current_Task_Name_Here"   function.
spinner(){
  pid=$!
  local message=$1
  spin='-\|/'
  i=0
  while kill -0 $pid 2>/dev/null
  do
    i=$(( (i+1) %4 ))
    printf "\r$message ${spin:$i:1}"
    sleep .14
  done
  printf "\n"
}

# Determine which package manager is installed. Exit if nothing is found.
if command -v apt &> /dev/null; then
  PKG_MANAGER="apt"
else
  if command -v pacman &> /dev/null; then
    PKG_MANAGER="pacman"
  else
    if command -v dnf &> /dev/null; then
      PKG_MANAGER="dnf"
    else
      echo "Error: Package manager (apt, pacman, or dnf) not found."
      exit 1
    fi
  fi
fi

# Declare packages we depend on. 
PACKAGES="git aria2 curl winetricks p7zip zenity"

# For Fedora specifically we add another package because it needs it for extracting archives.
if [ "$PKG_MANAGER" = "dnf" ]; then
    PACKAGES+=" p7zip-plugins"
fi

# If users request the software to be patched by launching the script with the --apply-patch parameter we also need firejail to restrict network access.
if [ "$1" = "--apply-patch" ]; then
    PACKAGES+=" firejail"
fi

# We add only the new packages that are currently not installed on the system to the package manager command that follows.
NEW_PACKAGES=()

# Check for packages to install
for PACKAGE in $PACKAGES; do
  if [ "$PKG_MANAGER" = "apt" ]; then
    if ! dpkg -s "$PACKAGE" &> /dev/null; then
      NEW_PACKAGES+=("$PACKAGE")
    fi
  elif [ "$PKG_MANAGER" = "pacman" ]; then
    if ! pacman -Q "$PACKAGE" &> /dev/null; then
      NEW_PACKAGES+=("$PACKAGE")
    fi
  elif [ "$PKG_MANAGER" = "dnf" ]; then
    if ! dnf list installed "$PACKAGE" &> /dev/null; then
      NEW_PACKAGES+=("$PACKAGE")
    fi
  fi
done

# Installing the new packages here, on whatever package manager the OS has.
echo "Installing dependencies:" "${NEW_PACKAGES[@]}"
if [ "$PKG_MANAGER" = "apt" ]; then
  sudo apt install "${NEW_PACKAGES[@]}" -y
elif [ "$PKG_MANAGER" = "pacman" ]; then
  sudo pacman -S "${NEW_PACKAGES[@]}" --noconfirm
elif [ "$PKG_MANAGER" = "dnf" ]; then
  sudo dnf install "${NEW_PACKAGES[@]}" -y
fi

git clone https://gitlab.com/xkero/rum.git/ $HOME/affinity_setup_tmp/rum &>/dev/null &
spinner "Cloning rum"

sudo cp $HOME/affinity_setup_tmp/rum/rum /usr/local/bin/rum

# Define some options for the aria2 download manager, so some of the following download commands don't end up being long and ugly.
ARIA2_PARAMETERS="-x8 --console-log-level=error --dir $HOME/affinity_setup_tmp/"

# Download then extract custom wine binaries specifically made to run Affinity apps better.
echo "Downloading Wine..."
aria2c $ARIA2_PARAMETERS --out ElementalWarrior-wine.7z  https://github.com/woafID/psychic-engine/releases/download/wine/ElementalWarrior-wine.7z

7z x $HOME/affinity_setup_tmp/ElementalWarrior-wine.7z -o$HOME/affinity_setup_tmp/ &>/dev/null &
spinner "Extracting"

# Copy downloaded wine binary to the folder that rum recognises.
sudo mkdir -p "/opt/wines"
sudo cp --recursive "$HOME/affinity_setup_tmp/ElementalWarrior-wine/wine-install" "/opt/wines/ElementalWarrior-8.14"

# Link wine to fix an issue because it does not have a 64bit binary.
sudo ln -s /opt/wines/ElementalWarrior-8.14/bin/wine /opt/wines/ElementalWarrior-8.14/bin/wine64

zenity --info --text="You may get prompted to install Wine Mono, in the next section. Please proceed with installing it. Other parts of the installation will be silent. Be patient."

mkdir $HOME/LinuxCreativeSoftware

# Ignore the "command not found" error. This is how it default agrees.
y | rum ElementalWarrior-8.14 $HOME/LinuxCreativeSoftware/Affinity wineboot --init &>/dev/null &

spinner "Initializing Wine"

# Zenity stuff are implemented this way instead of piping the winetricks command into it, because winetricks will abort installing if we do that. DONT ASK WHY!
zenity --progress --pulsate --title="Installing Dependencies" --text="This will take a few minutes... If you're curious, you can see the running installers in the System Monitor app." --no-cancel | sleep infinity &

# Installing Affinity's dependencies, such as dotnet.
rum ElementalWarrior-8.14 $HOME/LinuxCreativeSoftware/Affinity winetricks -q dotnet48 corefonts vcrun2015 &>/dev/null &
spinner "Installing dotnet48, corefonts, vcrun2015"
rum ElementalWarrior-8.14 $HOME/LinuxCreativeSoftware/Affinity wine winecfg -v win11 &>/dev/null &
spinner "Setting Windows version to 11"
killall zenity

# You can extract these files yourself manually from any windows 10 or 11 installation. Just copy the WinMetadata folder from System32 to this path i specified.
echo "Downloading WinMetadata..."
aria2c $ARIA2_PARAMETERS --out winmd.7z https://archive.org/download/win_metadata_mirror/winmd.7z
7z x $HOME/affinity_setup_tmp/winmd.7z -o$HOME/LinuxCreativeSoftware/Affinity/drive_c/windows/system32/WinMetadata &>/dev/null &
spinner "Extracting"

# Affinity setup's official page is being directed into a variable.
designer_url="https://store.serif.com/en-us/update/windows/designer/2/"
photo_url="https://store.serif.com/en-us/update/windows/photo/2/"
publisher_url="https://store.serif.com/en-us/update/windows/publisher/2/"

# Then we download the whole webpages with curl, in order to later extract a limited time download key that will allow us to download the setup files from their servers. The whole html page is being directed into a new variable.
designer_html_content=$(curl -gs "$designer_url")
photo_html_content=$(curl -gs "$photo_url")
publisher_html_content=$(curl -gs "$publisher_url")

# We extract the newest available version from the html content. So the latest_version only containts 2.2.0 for example.
latest_version=$(echo "$designer_html_content" | grep -o '2\.[0-9]*\.[0-9]*' | sort -V | tail -n 1)

# If the user launches the script with --apply-patch, then the latest version will be overwritten with an older one which has a compatible patch available.
if [ "$1" = "--apply-patch" ]; then
latest_version=2.3.1
fi

# Finally, from the downloaded html page we extract the newest download url by stripping everything else we dont need.
# These commands such as grep and sed are used to discard junk data from the html.
# This usable download url url will be directed into a variable which we then download.
designer_fileurl=$(echo "$designer_html_content" | grep "$latest_version.*\.exe" | grep -o 'https.*' | tr -d '"' | grep -v 'arm64' | sed 's/&amp;/\&/g' | sed '2d')
photo_fileurl=$(echo "$photo_html_content" | grep "$latest_version.*\.exe" | grep -o 'https.*' | tr -d '"' | grep -v 'arm64' | sed 's/&amp;/\&/g' | sed '2d')
publisher_fileurl=$(echo "$publisher_html_content" | grep "$latest_version.*\.exe" | grep -o 'https.*' | tr -d '"' | grep -v 'arm64' | sed 's/&amp;/\&/g' | sed '2d')


# We now download the installers with aria2. This command is equivalent of something like "wget https://example.com/example.file" 
# If the Affinity servers would expose these files directly, we wouldn't need to extract a one time download link from their site and the process would be simpler.
 echo
 echo "Downloading installers..."
 echo
 aria2c $ARIA2_PARAMETERS --out affinity-designer-msi-$latest_version.exe "$designer_fileurl"
 aria2c $ARIA2_PARAMETERS --out affinity-photo-msi-$latest_version.exe "$photo_fileurl"
 aria2c $ARIA2_PARAMETERS --out affinity-publisher-msi-$latest_version.exe "$publisher_fileurl"


# We already create shortcuts for these Apps.
# This Establishes language independence, as "Desktop" is different in various languages.
DESKTOP=$(xdg-user-dir DESKTOP)

zenity --info --text="Please proceed with all of the installers."

# We run the genuine setups that has been downloaded.
 rum ElementalWarrior-8.14 $HOME/LinuxCreativeSoftware/Affinity wine $HOME/affinity_setup_tmp/affinity-designer-msi-$latest_version.exe &>/dev/null &
spinner "Installing Designer"
rm -f $DESKTOP/Affinity\ Designer\ 2.lnk

 rum ElementalWarrior-8.14 $HOME/LinuxCreativeSoftware/Affinity wine $HOME/affinity_setup_tmp/affinity-photo-msi-$latest_version.exe &>/dev/null &
spinner "Installing Photo"
rm -f $DESKTOP/Affinity\ Photo\ 2.lnk

 rum ElementalWarrior-8.14 $HOME/LinuxCreativeSoftware/Affinity wine $HOME/affinity_setup_tmp/affinity-publisher-msi-$latest_version.exe &>/dev/null &
spinner "Installing Publisher"
rm -f $DESKTOP/Affinity\ Publisher\ 2.lnk


# Preventing crash reporting by renaming the binaries, because its not needed, and we dont want to report issues from unsupported OSes.
mv $HOME/LinuxCreativeSoftware/Affinity/drive_c/Program\ Files/Affinity/Designer\ 2/crashpad_handler.exe $HOME/LinuxCreativeSoftware/Affinity/drive_c/Program\ Files/Affinity/Designer\ 2/crashpad_handler.exe.bak
mv $HOME/LinuxCreativeSoftware/Affinity/drive_c/Program\ Files/Affinity/Photo\ 2/crashpad_handler.exe $HOME/LinuxCreativeSoftware/Affinity/drive_c/Program\ Files/Affinity/Photo\ 2/crashpad_handler.exe.bak
mv $HOME/LinuxCreativeSoftware/Affinity/drive_c/Program\ Files/Affinity/Publisher\ 2/crashpad_handler.exe $HOME/LinuxCreativeSoftware/Affinity/drive_c/Program\ Files/Affinity/Publisher\ 2/crashpad_handler.exe.bak


# VirusTotal results of the cracks for reference:
# Designer	https://www.virustotal.com/gui/file/a30ea21111d5d7e3b2d72c5f65ea0eb068aac0d4e355579f1afec5206793d387
# Photo		https://www.virustotal.com/gui/file/863d7d1f26fb61da452f6e6dc68a2d6ca6335c98d06541e3d9fddc703f74edf7
# Publisher	https://www.virustotal.com/gui/file/f43fbc18682196b3da9b5fd1ef82aad45172319617c3a3dc42b6f435f919367f

# If the user launches the script with --apply-patch, we swap out libaffinity.dll with one that skips activation.
if [ "$1" = "--apply-patch" ]; then
  echo "We are not responsible for any use of the products without valid licenses."
  echo "Applying patch..."
  echo
  aria2c $ARIA2_PARAMETERS --out patched_dlls.7z https://archive.org/download/patched_dlls.7z/patched_dlls.7z
  7z x $HOME/affinity_setup_tmp/patched_dlls.7z -o$HOME/affinity_setup_tmp/ &>/dev/null
  echo "Extracting..."
  cp -f $HOME/affinity_setup_tmp/patched_dlls/for_designer/libaffinity.dll $HOME/LinuxCreativeSoftware/Affinity/drive_c/Program\ Files/Affinity/Designer\ 2/
  cp -f $HOME/affinity_setup_tmp/patched_dlls/for_photo/libaffinity.dll $HOME/LinuxCreativeSoftware/Affinity/drive_c/Program\ Files/Affinity/Photo\ 2/
  cp -f $HOME/affinity_setup_tmp/patched_dlls/for_publisher/libaffinity.dll $HOME/LinuxCreativeSoftware/Affinity/drive_c/Program\ Files/Affinity/Publisher\ 2/
fi

# We create launcher scripts that will be executed by the .desktop files once users click them. 
echo "Creating launchers..."
mkdir $HOME/LinuxCreativeSoftware/Affinity/drive_c/launchers

echo 'rum ElementalWarrior-8.14 $HOME/LinuxCreativeSoftware/Affinity wine "$HOME/LinuxCreativeSoftware/Affinity/drive_c/Program Files/Affinity/Designer 2/Designer.exe"' > $HOME/LinuxCreativeSoftware/Affinity/drive_c/launchers/designer2.sh
echo 'rum ElementalWarrior-8.14 $HOME/LinuxCreativeSoftware/Affinity wine "$HOME/LinuxCreativeSoftware/Affinity/drive_c/Program Files/Affinity/Photo 2/Photo.exe"' > $HOME/LinuxCreativeSoftware/Affinity/drive_c/launchers/photo2.sh
echo 'rum ElementalWarrior-8.14 $HOME/LinuxCreativeSoftware/Affinity wine "$HOME/LinuxCreativeSoftware/Affinity/drive_c/Program Files/Affinity/Publisher 2/Publisher.exe"' > $HOME/LinuxCreativeSoftware/Affinity/drive_c/launchers/publisher2.sh

# Overwrite previous lines to disable network, if patching is requested.
# Adding --noblacklist=/sys/module until the firejail team fixes this shit. We cant create a new canvas otherwise.
if [ "$1" = "--apply-patch" ]; then
  echo 'firejail --noprofile --noblacklist=/sys/module --net=none rum ElementalWarrior-8.14 $HOME/LinuxCreativeSoftware/Affinity wine "$HOME/LinuxCreativeSoftware/Affinity/drive_c/Program Files/Affinity/Designer 2/Designer.exe"' > $HOME/LinuxCreativeSoftware/Affinity/drive_c/launchers/designer2.sh
  echo 'firejail --noprofile --noblacklist=/sys/module --net=none rum ElementalWarrior-8.14 $HOME/LinuxCreativeSoftware/Affinity wine "$HOME/LinuxCreativeSoftware/Affinity/drive_c/Program Files/Affinity/Photo 2/Photo.exe"' > $HOME/LinuxCreativeSoftware/Affinity/drive_c/launchers/photo2.sh
  echo 'firejail --noprofile --noblacklist=/sys/module --net=none rum ElementalWarrior-8.14 $HOME/LinuxCreativeSoftware/Affinity wine "$HOME/LinuxCreativeSoftware/Affinity/drive_c/Program Files/Affinity/Publisher 2/Publisher.exe"' > $HOME/LinuxCreativeSoftware/Affinity/drive_c/launchers/publisher2.sh
fi

# Making launchers executable
chmod u+x $HOME/LinuxCreativeSoftware/Affinity/drive_c/launchers/designer2.sh
chmod u+x $HOME/LinuxCreativeSoftware/Affinity/drive_c/launchers/photo2.sh
chmod u+x $HOME/LinuxCreativeSoftware/Affinity/drive_c/launchers/publisher2.sh

# Downloading icons from Serif's server.
mkdir -p $HOME/LinuxCreativeSoftware/Affinity/drive_c/launchers/icos
echo "Creating Designer icon..."
aria2c --console-log-level=warn --dir $HOME/LinuxCreativeSoftware/Affinity/drive_c/launchers/icos/ --out designer.svg https://cdn.serif.com/affinity/img/global/logos/affinity-designer-2-020520191502.svg &>/dev/null
echo "Creating Photo icon..."
aria2c --console-log-level=warn --dir $HOME/LinuxCreativeSoftware/Affinity/drive_c/launchers/icos/ --out photo.svg https://cdn.serif.com/affinity/img/global/logos/affinity-photo-2-020520191502.svg &>/dev/null
echo "Creating Publisher icon..."
aria2c --console-log-level=warn --dir $HOME/LinuxCreativeSoftware/Affinity/drive_c/launchers/icos/ --out publisher.svg https://cdn.serif.com/affinity/img/global/logos/affinity-publisher-2-020520191502.svg &>/dev/null

mkdir -p "$HOME/.local/share/applications"

#Create icons. There certainly is a better way to do this. We create .desktop files that launch the software.
#The backslashes (\) before and after the variable $HOME_DIR in the Exec line are used to escape the double quotes (") surrounding the path.
HOME_DIR=$HOME

DESKTOP_CONTENT_DESIGNER="[Desktop Entry]
Version=1.0
Type=Application
Terminal=false
Exec=/bin/bash -c \"$HOME_DIR/LinuxCreativeSoftware/Affinity/drive_c/launchers/designer2.sh\" %U
Name=Affinity Designer 2
Icon=$HOME_DIR/LinuxCreativeSoftware/Affinity/drive_c/launchers/icos/designer.svg
Categories=ConsoleOnly;System;"

echo "$DESKTOP_CONTENT_DESIGNER" > "$HOME/.local/share/applications/affinity_designer.desktop"


DESKTOP_CONTENT_PHOTO="[Desktop Entry]
Version=1.0
Type=Application
Terminal=false
Exec=/bin/bash -c \"$HOME_DIR/LinuxCreativeSoftware/Affinity/drive_c/launchers/photo2.sh\" %U
Name=Affinity Photo 2
Icon=$HOME_DIR/LinuxCreativeSoftware/Affinity/drive_c/launchers/icos/photo.svg
Categories=ConsoleOnly;System;"

echo "$DESKTOP_CONTENT_PHOTO" > "$HOME/.local/share/applications/affinity_photo.desktop"


DESKTOP_CONTENT_PUBLISHER="[Desktop Entry]
Version=1.0
Type=Application
Terminal=false
Exec=/bin/bash -c \"$HOME_DIR/LinuxCreativeSoftware/Affinity/drive_c/launchers/publisher2.sh\" %U
Name=Affinity Publisher 2
Icon=$HOME_DIR/LinuxCreativeSoftware/Affinity/drive_c/launchers/icos/publisher.svg
Categories=ConsoleOnly;System;"

echo "$DESKTOP_CONTENT_PUBLISHER" > "$HOME/.local/share/applications/affinity_publisher.desktop"

# Set renderrer to vulkan, to better support recent hardware. If you have issues, try replacing "vulkan" with "gl"
rum ElementalWarrior-8.14 $HOME/LinuxCreativeSoftware/Affinity winetricks renderer=vulkan &>/dev/null &
spinner "Switching API to Vulkan"

# Finally we remove the temporary directory.
rm -fr $HOME/affinity_setup_tmp
echo All done!
sleep 1.5
exit 0
