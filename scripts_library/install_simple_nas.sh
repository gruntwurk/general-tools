#!/usr/bin/env bash

# ----------------------------------------------------------------------------
#     Configure a Debian-based Linux Box (e.g. a Raspberry Pi) to be a 
#
#                           SIMPLE FILE SERVER (NAS)
# ----------------------------------------------------------------------------

# PARAMETERS:   (none)
# INSPIRATION:  https://pimylifeup.com/raspberry-pi-samba/
# AUTHOR:       polygot-jones -- 6/28/2021
# LINE ENDINGS: Be sure this file is saved with Unix line-endings.
# IDEMPOTENT?   No. Only run this once.
# PREREQUISITE: This assumes we're using the Raspbian operating system.
#               - It supports network discovery (mDNS) via Avahi
#               - It automatically mounts external USB drives (as /media/pi/something)
# References:   https://www.raspberrypi.org/documentation/configuration/nfs.md


# ============================================================================
#                                                     CHOOSE YOUR OPTIONS HERE
# ============================================================================
NAS_COMPUTER_NAME=nas
SHARE_DRIVE_AS=share
# Thus, the shared drive should be accessible as //nas/share 
# (or \\nas\share from Windows)

SHARE_PATH="(auto)"
# Currently, this script only knows how to auto-detect a single external drive 
# on a raspberry pi (which gets auto-mounted in /media/pi/)

SUPPORT_SAMBA=yes   # file sharing with Windows Clients
SUPPORT_NFS=yes     # file sharing with Linux and Mac clients
SUPPORT_DLNA=yes    # video streaming to Smart TVs
SUPPORT_MPD=yes     # audio streaming to jukebox software

DLNA_SUBFOLDER=movies
MPD_SUBFOLDER=music

# --------  You should not have to change anything below this line  ----------


# ============================================================================
#                                                      IMPORT HELPER FUNCTIONS
# ============================================================================
FULLY_QUALIFIED_SCRIPT_NAME="${BASH_SOURCE[0]}"
SCRIPT_NAME=${FULLY_QUALIFIED_SCRIPT_NAME##*.[/\\]}
SCRIPT_DIR="$( cd "$( dirname "$FULLY_QUALIFIED_SCRIPT_NAME" )" &> /dev/null && pwd )"
source $SCRIPT_DIR/helper_functions_debian.sh

# ============================================================================
#                                                                        BEGIN
# ============================================================================
LOG_FILE="${1:="/var/logs/$SCRIPT_NAME.log"}"
log_header "Start of $SCRIPT_NAME"

apt_update
sudo apt-get -y upgrade


# ============================================================================
#                                                    PREPARING THE MOUNT POINT
# ============================================================================

log_step "Changing the computer name to $NAS_COMPUTER_NAME"
sudo echo "$NAS_COMPUTER_NAME" > /etc/hostname 

if [ $SHARE_PATH == "(auto)" ]; then
	log_step "Auto-detecting the mount point of the external drive"
	# FIXME The following assumes that there is one, and only one, external drive mounted
	# (df -h = show the amount of free space on every device, human readable)
	# (-o means omit the match itself and only return the other part(s) of the matching line)
	SHARE_PATH=`df -h | egrep -o '/media/pi/.*?$'`
fi
sudo chmod 777 ${SHARE_PATH}


# ============================================================================
#                                                    INSTALL MISC. SYSTEM CODE
# ============================================================================
apt_install libnss-mdns "Name Service Switch (local network discovery) via Zeroconf, aka Apple Bonjour"

# This distro might not include NTFS support by default
apt_install ntfs-3g "NTFS file system driver"


# ============================================================================
#                                        INSTALL SAMBA (File-sharing Protocol)
# ============================================================================
if [ SUPPORT_SAMBA == "yes" ]; then
	apt_install "samba samba-common-bin" "SAMBA file sharing protocol (Windows style)"

	SHARE_COUNT=$( egrep -c "^\[$SHARE_DRIVE_AS\]" /etc/samba/smb.conf )
	if [ $SHARE_COUNT -LT 1 ]; then
		log_step "Configuring SAMBA for equating $SHARE_DRIVE_AS with $SHARE_PATH"
		sudo cat >> /etc/samba/smb.conf <<-EOF

			[$SHARE_DRIVE_AS]
			comment = RaspberryPi
			public = yes
			writeable = yes
			browsable = yes
			path = ${SHARE_PATH}
			create mask = 0777
			directory mask = 0777
		EOF
	fi

	# Restart Samba to apply changes
	sudo service smbd restart
fi


# ============================================================================
#                                          INSTALL NFS (File-sharing Protocol)
# ============================================================================
if [ SUPPORT_NFS == "yes" ]; then
	apt_install nfs-kernel-server "NFS file sharing protocol (Linux/Mac style)"

	log_step "Configuring NFS for equating $SHARE_DRIVE_AS with $SHARE_PATH"
	#NFS relies on the mount facility to "bind" this association at the system level 
	sudo mkdir -p /export/$SHARE_DRIVE_AS
	sudo chmod 777 /export
	sudo chmod 777 /export/$SHARE_DRIVE_AS
	mount_folder $SHARE_PATH /export/$SHARE_DRIVE_AS none 


	log_step "Configuring NFS for insecure guest access"
	NOBODY_COUNT=$( grep -c Nobody /etc/idmapd.conf )
	if [ $NOBODY_COUNT -LT 1 ]; then
		sudo cat >> /etc/idmapd.conf <<-EOF

			[Mapping]
			Nobody-User = nobody
			Nobody-Group = nogroup
		EOF
	fi
	
	log_step "Configuring NFS to share '$SHARE_DRIVE_AS'"
	PARENT_COUNT=$( grep -c "^/export " /etc/exports )
	if [ $PARENT_COUNT -LT 1 ]; then
		sudo echo "/export 192.168.1.0/24(rw,fsid=0,insecure,no_subtree_check,async)" >> /etc/exports
	fi
	SHARE_COUNT=$( grep -c "^/export/$SHARE_DRIVE_AS " /etc/exports )
	if [ $SHARE_COUNT -LT 1 ]; then
		sudo echo "/export/$SHARE_DRIVE_AS 192.168.1.0/24(rw,nohide,insecure,no_subtree_check,async)" >> /etc/exports
	fi

	sudo systemctl restart nfs-kernel-server
fi


# ============================================================================
#                                                                 INSTALL DLNA
# ============================================================================
if [ SUPPORT_DLNA == "yes" ]; then
	apt_install minidlna "Mini-DLNA for serving video streams"

	sudo mkdir -p $SHARE_PATH/$DLNA_SUBFOLDER
	
	config_change /etc/minidlna.conf media_dir "$SHARE_PATH/$DLNA_SUBFOLDER"
	
	sudo service minidlna start
fi



# ============================================================================
#                                                                  INSTALL MPD
# ============================================================================
if [ SUPPORT_MPD == "yes" ]; then
	apt_install mpd "Music Player Daemon"
	apt_install mpc "Music Player Client (command line)"
	
	conf_uncomment /etc/mpd.conf zeroconf_enabled

	sudo mkdir -p $SHARE_PATH/$MPD_SUBFOLDER
	
	sudo ln -s $SHARE_PATH/$MPD_SUBFOLDER /var/lib/mpd/music
	
	mpc update
	
	#avahi is the default linux implementation of Zeroconf 
	sudo service avahi daemon restart

fi