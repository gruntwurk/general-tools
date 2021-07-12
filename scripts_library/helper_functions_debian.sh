#!/usr/bin/env bash

# Some common BASH script functions.
# C Jones -- 6/4/2021

# Assumes global variable LOG_FILE

# BASH function parameters are not declared in the ().
# $0 = the name of the function
# $1 = the first parameter
# $n = the nth parameter
# $@ = all of the parameters (1 thru n) combined 


TIMESTAMP_FORMAT='+%A, %B %d, %Y  %H:%M:%S %Z'
SESSION_ID=$( date '+%Y%m%d-%H%M%S' )


# ============================================================================
#                                                                      LOGGING
# ============================================================================
start_log() {
    LOG_NAME=$1
    if [ -z $LOG_FILE ]; then
        LOG_FILE="/var/log/$LOG_NAME.log"
    fi
    log_header "Start of $LOG_NAME"
}


log() {
    echo "$@" &>> $LOG_FILE
}
show() {
    echo "------------------------------------------------------------------------------"
    echo "$@" 
    echo "------------------------------------------------------------------------------"
    echo "$@" &>> $LOG_FILE
}
log_header() {
    log ""
    log "=============================================================================="
    log "$@ -- `date \"$TIMESTAMP_FORMAT\"`"
    show "On $( hostname ) ($( hostname -I ))"
    log "=============================================================================="
}
log_step() {
    echo "" &>> $LOG_FILE
    echo ">>> $@" &>> $LOG_FILE
}
log_error() {
    echo "!!!!! ERROR !!!!! $@" &>> $LOG_FILE
}
log_not_yet() {
    echo "!!!!! NOT YET !!!!! $@ is not yet implemented in this script" &>> $LOG_FILE
}


# ============================================================================
#                                                           PACKAGE MANAGEMENT
# ============================================================================

# Updates the local copy of the APT catalog
apt_update() {
    sudo apt-get -yq update 2>> $LOG_FILE
}

# Manually upgrades the operating system
apt_dist_upgrade() {
    sudo apt-get -yq dist-upgrade 2>> $LOG_FILE
}

# Cleans up orphaned packages
apt_autoremove() {
    sudo apt-get autoremove 2>> $LOG_FILE

}

# Installs a package (headlessly)
apt_install() {
    local PKG_NAME=$1
    local DESCRIPTION=$2
    log_step "Installing $PKG_NAME ($DESCRIPTION)"
    sudo apt-get -yq install $PKG_NAME 2>> $LOG_FILE
    if [ $? -ne 0 ]; then
        log_error "apt-get returned code $?"
    fi
}

# Some distros don't have sudo installed by default 
apt_install_sudo() {
    if [ $( whoami ) == "root" ]; then
        local PKG_NAME=sudo
        local DESCRIPTION="super-user do"
        log_step "Installing $PKG_NAME ($DESCRIPTION)"
        apt-get -yq install sudo 2>> $LOG_FILE
        if [ $? -ne 0 ]; then
            log_error "apt-get returned code $?"
        fi
    fi
}



# ============================================================================
#                                                                CONFIGURATION
# ============================================================================

save_backup() {
    local CONFIG_FILE=$1
    mkdir -p /var/backup/$SESSION_ID
    cp -f $CONFIG_FILE /var/backup/$SESSION_ID
    log "Original $CONFIG_FILE saved to /var/backup/$SESSION_ID"
}


# Uncomments a setting line in a config file (if there is one, and only one)
# (Does not complain if there are zero or more than one.)
conf_uncomment() {
    local CONFIG_FILE=$1
    local OPTION=$2
    local OPTION_COUNT=$( egrep -c "^#\s*$OPTION[= \t]" $CONFIG_FILE )
    if [ $OPTION_COUNT -eq 1 ]; then
        log "Setting was: $( egrep "^#\s*$OPTION[= \t]" $CONFIG_FILE )"
        sudo sed -r -e "s/^#\s*($OPTION[= \t].*)/\1/" -iorig $CONFIG_FILE 2>> $LOG_FILE
        log "Setting now: $( egrep "^$OPTION[= \t]" $CONFIG_FILE )"
    fi
}

# Changes an option in a config file, as long as there is one, and only one, such existing option.
# The option name must be the first non-space on the line.
# If the option name is followed by an equal sign, it is preserved.
# The rest of the line is replaced with the new value.
# Before complaining if such an option isn't found, it tries calling conf_uncomment first.
# If it still can't find one, it reports an error.
conf_change() {
    local CONFIG_FILE=$1
    local OPTION=$2
    local NEW_VALUE=$3
    # See if such an option exists (at the start of a line)
    local OPTION_COUNT=$( egrep -c "^\s*$OPTION[= \t]" $CONFIG_FILE )
    if [ $OPTION_COUNT -lt 1 ]; then
        # Maybe it's been commented out. Try uncommenting it, then count again.
        conf_uncomment $CONFIG_FILE $OPTION
        OPTION_COUNT=$( egrep -c "^\s*$OPTION[= \t]" $CONFIG_FILE )
    fi

    if [ $OPTION_COUNT -lt 1 ]; then
        log_error "No such option as $OPTION exists within $CONFIG_FILE -- nothing changed."
    elif [ $OPTION_COUNT -gt 1 ]; then
        log_error "Multiple ambiguous $OPTION lines exist within $CONFIG_FILE -- nothing changed."
    else
        log "Setting was: $( egrep "^\s*$OPTION[= \t]" $CONFIG_FILE )"
        sudo sed -r -e "s~^(\s*$OPTION)([= \t]+).*~\1\2$NEW_VALUE~" -iorig $CONFIG_FILE 2>> $LOG_FILE
        log "Setting now: $( egrep "^\s*$OPTION[= \t]" $CONFIG_FILE )"
    fi
}

# ============================================================================
#                                                                  FILE SYSTEM
# ============================================================================

check_computer_name() {
    MACHINE_NAME=${1:-$( hostname )}
    log_step "Checking the computer name."

    if [ $( hostname ) == "$MACHINE_NAME" ]; then
        log "Verified that the computer name is $MACHINE_NAME"
    else
        show "Changing the computer name from $( hostname ) to $MACHINE_NAME"
        sudo echo "$MACHINE_NAME" > /etc/hostname 
    fi

    LOOPBACK_COUNT=$( egrep -c "127.0.0.1\s+$MACHINE_NAME" /etc/hosts )
    if [ $LOOPBACK_COUNT -lt 1 ]; then
        save_backup /etc/hosts
        log "Adding a loopback for $MACHINE_NAME in /etc/hosts"
        echo "127.0.0.1          $MACHINE_NAME" >> /etc/hosts
    fi
}

# (Re)Declares a folder to be mounted or bound
# If the PARTITION_TYPE (3rd parameter) is "bind", then the bind option will be used
mount_folder() {
    local CONFIG_FILE="/etc/fstab"
    local SOURCE_FOLDER=$1
    local MOUNT_POINT=$2
    local PARTITION_TYPE=$3
    local CREDENTIALS=$4
    local MOUNT_OPTIONS=
    save_backup $CONFIG_FILE

    if [ "$PARTITION_TYPE" == "bind" ]; then
        PARTITION_TYPE=none
        MOUNT_OPTIONS=bind
    elif [ -z "$CREDENTIALS" ]; then
        MOUNT_OPTIONS="uid=1000,gid=1000,iocharset=utf8"
    else
        MOUNT_OPTIONS="$CREDENTIALS,uid=1000,gid=1000,iocharset=utf8"
    fi
    show "Mounting $SOURCE_FOLDER ($PARTITION_TYPE) as $MOUNT_POINT with $MOUNT_OPTIONS"
    sudo mkdir -p $MOUNT_POINT && sudo chmod -R 777 $MOUNT_POINT && sudo chown -R $USER:$USER $MOUNT_POINT 

    local FSTAB_LINE="$SOURCE_FOLDER $MOUNT_POINT $PARTITION_TYPE $MOUNT_OPTIONS 0 0" 
    show "FSTAB line: $FSTAB_LINE"
    local EXISTING_COUNT=$( egrep -c "^[^ ]* $MOUNT_POINT" $CONFIG_FILE )
    if [ $EXISTING_COUNT -lt 1 ]; then
        echo "$FSTAB_LINE" >> $CONFIG_FILE
    elif [ $EXISTING_COUNT -eq 1 ]; then
        sudo sed -r -e "s~^$SOURCE_FOLDER .*$~$FSTAB_LINE~" -iorig $CONFIG_FILE 2>> $LOG_FILE
    else
        log_error "Duplicate existing FSTAB entries found for $SOURCE_FOLDER."
    fi
    sudo mount -a
}
