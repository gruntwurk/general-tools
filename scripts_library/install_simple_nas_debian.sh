#!/usr/bin/env bash

# ----------------------------------------------------------------------------
#     Configure a Debian-based Linux Box (e.g. a Raspberry Pi) to be a 
#
#                           SIMPLE FILE SERVER (NAS)
# ----------------------------------------------------------------------------

# TARGET OS:    Debian-Based Linux
# PARAMETERS:   (none)
# INSPIRATION:  https://pimylifeup.com/raspberry-pi-samba/
# AUTHOR:       polygot-jones -- 6/28/2021
# LINE ENDINGS: Be sure this file is saved with Unix line-endings.
# IDEMPOTENT:   There is no harm is running this script multiple times.
# References:   https://www.raspberrypi.org/documentation/configuration/nfs.md


# ============================================================================
#                                                     CHOOSE YOUR OPTIONS HERE
# ============================================================================
USER=pi

PARTITION_TYPE=ntfs   # (ntfs, linux, fat32, exfat, hpfs, ext4, etc.)
# Currently, we assume that there is one, and only one, device with this partition type
SHARE_PATH=/media/pi/share  # mounting point to use

MACHINE_NAME=nas
SHARE_DRIVE_AS=share
# Thus, the shared drive should be accessible as //nas/share 
# (or \\nas\share from Windows)

SUPPORT_SAMBA=YES   # file sharing with Windows Clients
SUPPORT_NFS=YES     # file sharing with Linux and Mac clients
SUPPORT_DLNA=YES    # video streaming to Smart TVs
SUPPORT_MPD=YES     # audio streaming to jukebox software

DLNA_SUBFOLDER=movies
MPD_SUBFOLDER=music

# --------  You should not have to change anything below this line  ----------


# ============================================================================
#                                    IMPORT HELPER FUNCTIONS AND START LOGGING
# ============================================================================
FULLY_QUALIFIED_SCRIPT_NAME="${BASH_SOURCE[0]}"
SCRIPT_NAME=${FULLY_QUALIFIED_SCRIPT_NAME##*.[/\\]}
SCRIPT_DIR="$( cd "$( dirname "$FULLY_QUALIFIED_SCRIPT_NAME" )" &> /dev/null && pwd )"
source $SCRIPT_DIR/helper_functions_debian.sh
start_log "$SCRIPT_NAME"

# ============================================================================
#                                                        MISC. SYSTEM SETTINGS
# ============================================================================

check_computer_name $MACHINE_NAME

# ============================================================================
#                                                    INSTALL MISC. SYSTEM CODE
# ============================================================================

apt_update
sudo apt-get -y upgrade

# Just in case the installed distro doesn't include these by default:
apt_install avahi-daemon "local network discovery, aka Zeroconf, aka Apple Bonjour"
apt_install libnss-mdns "Name Service Switch plugin for .local resolution (i.e. an avahi client)"
apt_install ntfs-3g "NTFS file system driver"

# ============================================================================
#                                                     MOUNT THE EXTERNAL DRIVE
# ============================================================================

log_step "Auto-detecting the external drive device"
# FIXME -- this assumes that there is one, and only one, device with this partition type
DEVICE_NAME="$( blkid | egrep -i "type=\"$PARTITION_TYPE\"" | egrep -o '/dev/\w+' )"
# DEVICE_NAME is now something like /dev/sda1

mount_folder $DEVICE_NAME $SHARE_PATH $PARTITION_TYPE


# ============================================================================
#                                        INSTALL SAMBA (File-sharing Protocol)
# ============================================================================
if [ $SUPPORT_SAMBA == "YES" ]; then
	apt_install "samba samba-common-bin" "SAMBA file sharing protocol (Windows style)"

	SHARE_COUNT=$( egrep -c "^\[$SHARE_DRIVE_AS\]" /etc/samba/smb.conf )
	if [ $SHARE_COUNT -lt 1 ]; then
		log_step "Configuring SAMBA for equating $SHARE_DRIVE_AS with $SHARE_PATH"
		save_backup /etc/samba/smb.conf
		sudo cat >> /etc/samba/smb.conf <<-EOF

			[$SHARE_DRIVE_AS]
			comment = Network-Atttached-Storage
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
if [ $SUPPORT_NFS == "YES" ]; then
	apt_install nfs-kernel-server "NFS file sharing protocol (Linux/Mac style)"

	log_step "Configuring NFS for equating $SHARE_DRIVE_AS with $SHARE_PATH"
	#NFS relies on the mount facility to "bind" this association at the system level 
	sudo mkdir -p /export/$SHARE_DRIVE_AS
	sudo chmod -R 777 /export
	mount_folder $SHARE_PATH /export/$SHARE_DRIVE_AS bind 


	log_step "Configuring NFS for insecure guest access"
	save_backup /etc/idmapd.conf
	NOBODY_COUNT=$( grep -c Nobody /etc/idmapd.conf )
	if [ $NOBODY_COUNT -lt 1 ]; then
		sudo cat >> /etc/idmapd.conf <<-EOF

			[Mapping]
			Nobody-User = nobody
			Nobody-Group = nogroup
		EOF
	fi
	
	log_step "Configuring NFS to share '$SHARE_DRIVE_AS'"
	save_backup /etc/exports
	PARENT_COUNT=$( grep -c "^/export " /etc/exports )
	if [ $PARENT_COUNT -lt 1 ]; then
		sudo echo "/export 192.168.1.0/24(rw,fsid=0,insecure,no_subtree_check,async)" >> /etc/exports
	fi
	SHARE_COUNT=$( grep -c "^/export/$SHARE_DRIVE_AS " /etc/exports )
	if [ $SHARE_COUNT -lt 1 ]; then
		sudo echo "/export/$SHARE_DRIVE_AS 192.168.1.0/24(rw,nohide,insecure,no_subtree_check,async)" >> /etc/exports
	fi

	sudo systemctl restart nfs-kernel-server
fi


# ============================================================================
#                                                                 INSTALL DLNA
# ============================================================================
if [ $SUPPORT_DLNA == "YES" ]; then
	apt_install minidlna "Mini-DLNA for serving video streams"

	sudo mkdir -p $SHARE_PATH/$DLNA_SUBFOLDER
	
	save_backup /etc/minidlna.conf
	conf_change /etc/minidlna.conf media_dir "$SHARE_PATH/$DLNA_SUBFOLDER"
	
	sudo service minidlna start
fi



# ============================================================================
#                                                                  INSTALL MPD
# ============================================================================
if [ $SUPPORT_MPD == "YES" ]; then
	apt_install mpd "Music Player Daemon"
	apt_install mpc "Music Player Client (command line)"
	
	sudo mkdir -p $SHARE_PATH/$MPD_SUBFOLDER
	sudo ln -s $SHARE_PATH/$MPD_SUBFOLDER /var/lib/mpd/music
	
	save_backup /etc/mpd.conf
	conf_uncomment /etc/mpd.conf zeroconf_enabled
	
	mpc update
fi



# ============================================================================
#                                                                      CLEANUP
# ============================================================================

sudo service avahi-daemon restart

