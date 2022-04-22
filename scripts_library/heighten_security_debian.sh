#!/usr/bin/env bash

# ----------------------------------------------------------------------------
#          Heighten Security on a (Debian-Based) Linux Server
# ----------------------------------------------------------------------------

# PARAMETERS:   (none)
# INSPIRATION:  NetworkChuck's video: https://www.youtube.com/watch?v=ZhMw53Ud2tY
# AUTHOR:       polygot-jones -- 6/3/2021
# LINE ENDINGS: Be sure this file is saved with Unix line-endings.
# IDEMPOTENT:   There is no harm is running this script multiple times.

# ============================================================================
#                                                     CHOOSE YOUR OPTIONS HERE
# ============================================================================
SSH_PORT=22
# HTTP_PORT=80/tcp
# HTTPS_PORT=8080/tcp
BLOCK_PINGS="YES" # Anything but YES means no

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
#                                                    INSTALL MISC. SYSTEM CODE
# ============================================================================

apt_update
apt_dist_upgrade

# ============================================================================
#                                                     ENABLE AUTOMATIC UPDATES
# ============================================================================

log_step "Enabling automatic updates"
apt_install unattended-upgrades "Standard Debian package for automatic updates"
dpkg-reconfigure --default-priority -u unattended-upgrades 2>> $LOG_FILE

# ============================================================================
#                                                             LIMIT SSH ACCESS
# ============================================================================

save_backup /etc/ssh/sshd_config

# This assumes that there is at least one non-root user with a working public 
# key established in their ~/.ssh/. 
#
# IMPORTANT: Ensure that they are in the `sudo` group, as that will be the
# only way to perform operations requiring root privileges.

# Lock down SSH
log_step "Denying logging in (via SSH) as root"
conf_change /etc/ssh/sshd_config PermitRootLogin no

log_step "Denying logging in (via SSH) with a password (thus a keypair is required)"
conf_change /etc/ssh/sshd_config PasswordAuthentication no

log_step "Restricting SSH access to IPv4 (not IPv6)"
conf_change /etc/ssh/sshd_config AddressFamily inet

# Specify the (non-default) port for SSH
if [ "$SSH_PORT" != "22" ]; then
    log_step "Changing SSH port to $SSH_PORT"
    conf_change /etc/ssh/sshd_config Port $SSH_PORT
fi

# We can't restart sshd here, because vagrant needs the current SSH connection to finish the provisioning.
# sudo systemctl restart sshd 2>> $LOG_FILE

# ============================================================================
#                                                           CONFIGURE FIREWALL
# ============================================================================

# If you are not sure what ports to leave open, this will show you what ports 
# have been used to connect thus far...
#
#     sudo ss -tupln

log_step "Installing UFW (an easy way to configure the firewall)"
sudo apt-get -yq install ufw 2>> $LOG_FILE

log_step "Allowing port $SSH_PORT"
sudo ufw allow $SSH_PORT 2>> $LOG_FILE
if [ -v HTTP_PORT ]; then
    log_step "Allowing port $HTTP_PORT"
    sudo ufw allow $HTTP_PORT 2>> $LOG_FILE
fi
if [ -v HTTPS_PORT ]; then
    log_step "Allowing port $HTTPS_PORT"
    sudo ufw allow $HTTPS_PORT 2>> $LOG_FILE
fi
# We can't enable the firewall at this point. It must be done later.
# sudo ufw enable 2>> $LOG_FILE
# sudo ufw status &>> $LOG_FILE

if [ "$BLOCK_PINGS" == "YES" ]; then
    log_step "Blocking pings."
    sudo echo "" >> /etc/ufw/before.rules
    sudo echo "# block pings" >> /etc/ufw/before.rules
    sudo echo "-A ufw-before-input -p icmp --icmp-type echo-request -j DROP" \
        >> /etc/ufw/before.rules 2>> $LOG_FILE
fi

# ============================================================================
#                                                                      CLEANUP
# ============================================================================

log_header "Done (Security Heightened)"
log
show "NOTE: SSH restrictions will not be applied until after a reboot."
show "NOTE: The firewall will not be active until the following command is entered: sudo wfw enable."
log
