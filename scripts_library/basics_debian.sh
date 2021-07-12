#!/usr/bin/env bash

# ----------------------------------------------------------------------------
#          Basic Configuration for a (Debian-Based) Linux Server
# ----------------------------------------------------------------------------

# PARAMETERS:   (none)
# INSPIRATION:  NetworkChuck's video: https://www.youtube.com/watch?v=ZhMw53Ud2tY
# AUTHOR:       polygot-jones -- 7/12/2021
# LINE ENDINGS: Be sure this file is saved with Unix line-endings.
# IDEMPOTENT:   There is no harm is running this script multiple times.

# ============================================================================
#                                                     CHOOSE YOUR OPTIONS HERE
# ============================================================================
TARGET_MACHINE=PI                      # (PI, VAGRANT, or GUEST)
SYSTEM_TIMEZONE="America/Los_Angeles"  # per: timedatectl list-timezones

ROUTER_NAME=
ROUTER_PW=

if [ "$TARGET_MACHINE" == "PI" ]; then
    USER_ID=pi
    USER_NAME="Raspberry Pi Administrator" 
    USER_GROUPS=sudo
elif [ "$TARGET_MACHINE" == "VAGRANT" ]; then
    USER_ID=vagrant
    USER_NAME="Vagrant Developer" 
    USER_GROUPS=sudo,vagrant
else
    USER_ID=guest
    USER_NAME="Guest User" 
    USER_GROUPS=
fi

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

# These must be the very first things
check_computer_name
apt_install_sudo

# ============================================================================
#                                                    INSTALL MISC. SYSTEM CODE
# ============================================================================

apt_update
apt_dist_upgrade

# Just in case the installed distro doesn't include these by default:
apt_install avahi-daemon "local network discovery, aka Zeroconf, aka Apple Bonjour"
apt_install libnss-mdns "Name Service Switch plugin for .local resolution (i.e. an avahi client)"
apt_install ntfs-3g "NTFS file system driver"

# ============================================================================
#                                                           CREATE A SUDO USER
# ============================================================================

log_step "Creating user account: $USER_ID ($USER_NAME) with default password of $USER_ID" 
USER_HOME="/home/$USER_ID"
if [ -d $USER_HOME ]; then
    log "User $USER_ID already exists."
else
    useradd -m -c "$USER_NAME" -s /bin/bash -G $USER_GROUPS -U $USER_ID
    echo "$USER_ID:$USER_ID" | chpasswd
fi

sudo -u $USER_ID mkdir -p $USER_HOME/.ssh
if [ ! -f $USER_HOME/.ssh/authorized_keys ]; then
    if [ -f /root/.ssh/authorized_keys ]; then
        log "Copying ssh authorized keys from root to $USER_ID"
        sudo cp /root/.ssh/authorized_keys $USER_HOME/.ssh/authorized_keys
        sudo chown $USER_ID:$USER_ID $USER_HOME/.ssh/authorized_keys
    fi
fi

if [ -d /boot/firmware/rpi4_config ]; then
    log "Copying files from /boot/firmware/rpi4_config to $USER_HOME"
    sudo cp -r /boot/firmware/rpi4_config $USER_HOME
fi

# ============================================================================
#                                                          INSTALL MISC. TOOLS
# ============================================================================

log_step "Installing misc. command lines tools (dos2unix, etc.)"
apt_install dos2unix    "converts line-endings"
apt_install htop        "system stats"
apt_install ncdu        "manages disk usage"
apt_install ufw         "simplified firewall configuring"
apt_install asciidoctor "AsciiDoc compiler (AsciiDoctor)"

# ============================================================================
#                                                                SYSTEM CONFIG
# ============================================================================

# ##############################################   Time Zone
log_step "Setting time zone to $SYSTEM_TIMEZONE"
sudo timedatectl set-timezone $SYSTEM_TIMEZONE 2>> $LOG_FILE


# ##############################################   Wi-Fi Password
WIFI_FILE=/etc/network/interfaces.d/wlan0
if [ -n $ROUTER_NAME ]; then
    if [ -f $WIFI_FILE ]; then
        save_backup $WIFI_FILE
        conf_change $WIFI_FILE wpa-ssid $ROUTER_NAME
        conf_change $WIFI_FILE wpa-psk $ROUTER_PW
    fi
fi


# ============================================================================
#                                                                      CLEANUP
# ============================================================================

apt_autoremove
sudo service avahi-daemon restart 2>> $LOG_FILE


log_header "RECAP"      # this shows the time zone and the hostname/IP address
log ""
log "AsciiDoctor = $( asciidoctor --version )"  
log ""
log "Firewall `sudo ufw status`"
log ""
log ""
