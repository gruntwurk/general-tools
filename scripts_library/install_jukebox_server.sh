#!/usr/bin/env bash

# ----------------------------------------------------------------------------
#                     Install Music Player Daemon (MPD)
# ----------------------------------------------------------------------------

# TARGET OS:    Debian-Based Linux
# PARAMETERS:   (none)
# INSPIRATION:  
# AUTHOR:       polygot-jones -- 7/12/2021
# LINE ENDINGS: Be sure this file is saved with Unix line-endings.
# IDEMPOTENT:   There is no harm is running this script multiple times.
# References:   https://mpd.fandom.com/wiki/Music_Player_Daemon_Wiki

# ============================================================================
#                                                     CHOOSE YOUR OPTIONS HERE
# ============================================================================
# If installing this on the same box as the NAS, then set the FILE_SHARE_TYPE 
# to local and reference the music folder directly.

SAME_BOX_AS_NAS=YES
if [ $SAME_BOX_AS_NAS == "YES" ]; then
	FILE_SHARE_TYPE=local
	MUSIC_FOLDER=/media/pi/share/music
	FILE_SHARE_CREDENTIALS=guest
else
	MUSIC_FOLDER=//nas/share/music
	FILE_SHARE_TYPE=cifs 
	#FILE_SHARE_TYPE=nfs 
	FILE_SHARE_CREDENTIALS=guest
	# If access to the music folder is restricted, then replace guest with username=yourusername,password=yourpassword.
fi


# ============================================================================
#                                                      IMPORT HELPER FUNCTIONS
# ============================================================================
FULLY_QUALIFIED_SCRIPT_NAME="${BASH_SOURCE[0]}"
SCRIPT_NAME=${FULLY_QUALIFIED_SCRIPT_NAME##*.[/\\]}
SCRIPT_DIR="$( cd "$( dirname "$FULLY_QUALIFIED_SCRIPT_NAME" )" &> /dev/null && pwd )"
source $SCRIPT_DIR/helper_functions_debian.sh
start_log "$SCRIPT_NAME"

# ============================================================================
#                                                    INSTALL MISC. SYSTEM CODE
# ============================================================================

apt_update
sudo apt-get -y upgrade

# Just in case the installed distro doesn't include these by default:
apt_install avahi-daemon "local network discovery, aka Zeroconf, aka Apple Bonjour"
apt_install libnss-mdns "Name Service Switch plugin for .local resolution (i.e. an avahi client)"

# ============================================================================
#                                                                  INSTALL MPD
# ============================================================================
apt_install mpd "Music Player Daemon"
apt_install mpc "Music Player Client (command line)"

save_backup /etc/mpd.conf
conf_uncomment /etc/mpd.conf zeroconf_enabled

if [ $FILE_SHARE_TYPE != "local" ]; then
	mount_folder $MUSIC_FOLDER /mnt/music $FILE_SHARE_TYPE $FILE_SHARE_CREDENTIALS
	sudo ln -s /mnt/music /var/lib/mpd/music
else
	sudo ln -s $MUSIC_FOLDER /var/lib/mpd/music
fi
mpc update

# ============================================================================
#                                                                      CLEANUP
# ============================================================================

#avahi is the default linux implementation of Zeroconf 
sudo service avahi-daemon restart

#To access music on a USB stick... 
#apt_install usbmount "Allows a USB stick to be mounted as a file system"
#sudo ln -s /media/ /var/lib/mpd/music/


