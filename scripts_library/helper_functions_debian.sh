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


# ============================================================================
#                                                                      LOGGING
# ============================================================================
log() {
    echo "$@" &>> $LOG_FILE
}
log_header() {
    echo "" &>> $LOG_FILE
    echo "==============================================================================" &>> $LOG_FILE
    echo "$@ -- `date \"$TIMESTAMP_FORMAT\"`" &>> $LOG_FILE
    echo "==============================================================================" &>> $LOG_FILE
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

# Installs a package (headlessly)
apt_install() {
    local PKG_NAME=$1
    local DESCRIPTION=$2
    log_step "Installing $PKG_NAME ($DESCRIPTION)"
    sudo apt-get -yq install $PKG_NAME 2>> $LOG_FILE
    if [ $? -ne 0 ]; then
        log_error "apt_get returned code $?"
    elif
}


# ============================================================================
#                                                                CONFIGURATION
# ============================================================================

# Uncomments a setting line in a config file (if there is one, and only one)
# (Does not complain if there are zero or more than one.)
conf_uncomment() {
    local CONFIG_FILE=$1
    local OPTION=$2
    local OPTION_COUNT=$( grep -c '^#\s*$OPTION' $CONFIG_FILE )
    if [ $OPTION_COUNT -eq 1 ]; then
        log "Setting was: $( grep '^#\s*$OPTION' $CONFIG_FILE )"
        sudo sed -e "s/^#\s($OPTION)/\1/" -iorig $CONFIG_FILE 2>> $LOG_FILE
        log "Setting now: $( grep '^$OPTION' $CONFIG_FILE )"
    fi
}

# Changes a setting in a config file, as long as there is one, and only one, such existing setting.
# Before complaining if one isn't found, it tries calling conf_uncomment first.
# If it still can't find one, it reports an error.
conf_change() {
    local CONFIG_FILE=$1
    local OPTION=$2
    local NEW_VALUE=$3
    # See if such an option exists (at the start of a line)
    local OPTION_COUNT=$( grep -c '^\s*$OPTION' $CONFIG_FILE )
    if [ $OPTION_COUNT -lt 1 ]; then
        # Maybe it's been commented out. Try uncommenting it, then count again.
        conf_uncomment $CONFIG_FILE $OPTION
        OPTION_COUNT=$( grep -c '^\s*$OPTION' $CONFIG_FILE )
    fi

    if [ $OPTION_COUNT -lt 1 ]; then
        log_error "No such option as $OPTION exists within $CONFIG_FILE -- nothing changed."
    elif [ $OPTION_COUNT -gt 1 ]; then
        log_error "No such option as $OPTION exists within $CONFIG_FILE -- nothing changed."
    else
        log "Setting was: $( grep '^\s*$OPTION' $CONFIG_FILE )"
        sudo sed -e "s~^(\s*$OPTION)([= ])\.*~\1\2$NEW_VALUE~" -iorig $CONFIG_FILE 2>> $LOG_FILE
        log "Setting now: $( grep '^\s*$OPTION' $CONFIG_FILE )"
    fi




# ============================================================================
#                                                                  FILE SYSTEM
# ============================================================================

# (Re)Declares a folder to be mounted or bound
# If the FILE_SYSTEM_TYPE (3rd parameter) is "none", then the bind option will be used
mount_folder() {
    local CONFIG_FILE="/etc/fstab"
    local SOURCE_FOLDER=$1
    local MOUNT_POINT=$2
    local FILE_SYSTEM_TYPE=$3
    local CREDENTIALS=$4
    if [ $FILE_SYSTEM_TYPE == "none" ]; then
        local MOUNT_OPTIONS="bind"
    else
        local MOUNT_OPTIONS="$CREDENTIALS,uid=1000,gid=1000,iocharset=utf8"
    fi
    sudo mkdir -p $MOUNT_POINT
    local FSTAB_LINE="$SOURCE_FOLDER $MOUNT_POINT $FILE_SYSTEM_TYPE $MOUNT_OPTIONS 0 0" 
    local EXISTING_COUNT=$( grep -c '^[^ ]*$MOUNT_POINT ' )
    if [ $EXISTING_COUNT -lt 1 ]; then
        echo "$FSTAB_LINE" >> $CONFIG_FILE
    elif [ $EXISTING_COUNT -eq 1 ]; then
        sudo sed -e "s/^$SOURCE_FOLDER .*$)/$FSTAB_LINE/" -iorig $CONFIG_FILE 2>> $LOG_FILE
    else
        log_error "Duplicate existing FSTAB entries found for $MOUNT_POINT."
    fi
    sudo mount -a
}
