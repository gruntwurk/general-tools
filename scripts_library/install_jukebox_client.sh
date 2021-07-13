#!/usr/bin/env bash

# ----------------------------------------------------------------------------
#                     Install the Raspberry Pi Jukebox app
#        (Can be on the same box as the Music Player Daemon, if desired)
# ----------------------------------------------------------------------------

# STATUS:        INCOMPLETE!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

# TARGET OS:     Debian-Based Linux
# PARAMETERS:    (none)
# INSPIRATION:   
# AUTHOR:        polygot-jones -- 7/7/2021
# LINE ENDINGS:  Be sure this file is saved with Unix line-endings.
# IDEMPOTENT:    There is no harm is running this script multiple times.
# References:    https://mpd.fandom.com/wiki/Music_Player_Daemon_Wiki

# ============================================================================
#                                                     CHOOSE YOUR OPTIONS HERE
# ============================================================================

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
#                                                   INSTALL JUKEBOX SOURCECODE
# ============================================================================
git clone https://github.com/mark-me/Pi-Jukebox
apt_install python-pip
sudo python pi-jukebox.py


