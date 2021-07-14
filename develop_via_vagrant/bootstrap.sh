#!/usr/bin/env bash

# A script to provision a Debian-based Linux distro for Python development.
# C Jones -- 5/14/2021

# LINE ENDINGS: Be sure this file is saved with Unix line-endings.

# IDEMPOTENT:   There is no harm is running this script multiple times.

# AVOID $HOME:  When this script is invoked as part of VAGRANT UP (i.e. as 
#               specified via Vagrantfile), it executes while being logged in
#               as root (and $HOME is /root). However, the VAGRANT SSH command
#               logs you in as "vagrant" and $HOME is /home/vagrant. This 
#               script therefore avoids using ~ and $HOME altogether (except 
#               as a temp folder for wget).
LOG_FILE="/vagrant/bootstrap.log"
SCRIPT_DIR="/vagrant/scripts_library"

# ============================================================================
#                                                             Helper Functions
# ============================================================================

# Import the common helper functions
if [ -f $SCRIPT_DIR/helper_functions.sh ]; then 
	source $SCRIPT_DIR/helper_functions.sh
else
	echo "$SCRIPT_DIR/helper_functions.sh does not exist! Aborting." >> $LOG_FILE
	exit
fi

# Define a few more just for this script
go_noninteractive() {
	log_step "Setting dpkg-preconfigure to noninteractive (for the apt-get calls in this script)"
	sudo sed -i 's/\(dpkg-preconfigure\) --apt/\1 --frontend=noninteractive --apt/' /etc/apt/apt.conf.d/70debconf 2>> $LOG_FILE
}
revert_to_interactive() {
	log_step "Resetting dpkg-preconfigure back to interactive (for future apt-get calls)"
	sudo sed -i 's/ --frontend=noninteractive//' /etc/apt/apt.conf.d/70debconf 2>> $LOG_FILE
}
chown_dev() {
    sudo chown $DEVELOPER_ID:$DEVELOPER_ID $* 2>> $LOG_FILE
}




log_header "Start of bootstrap.sh"

go_noninteractive

# ============================================================================
#                                                               LOCAL SETTINGS
# ============================================================================
if [ -f "/vagrant/bootstrap_local.sh" ]; then
	log_step "Loading bootstrap_local.sh" 
	source /vagrant/bootstrap_local.sh
else 
	log "Required bootstrap_local.sh not found! -- Aborting"
	exit
fi
log "Configuration settings to be used:"
log ""
log "SYSTEM_TIMEZONE          = $SYSTEM_TIMEZONE"
log "DEVELOPER_ID             = $DEVELOPER_ID" 
log "DEVELOPER_NAME           = $DEVELOPER_NAME" 
log "DEVELOPER_EMAIL          = $DEVELOPER_EMAIL" 
log "GITHUB_USER_ID           = $GITHUB_USER_ID" 
log "GITHUB_APP_TOKEN         = $GITHUB_APP_TOKEN" 
log "SECURITY_LEVEL           = $SECURITY_LEVEL" 
log ""  
log "BUILD_PYTHON_FROM_SOURCE = $BUILD_PYTHON_FROM_SOURCE"
log "PYTHON_PACKAGES          = $PYTHON_PACKAGES"
log "INSTALL_MERCURIAL        = $INSTALL_MERCURIAL"
log "INSTALL_BAZAAR           = $INSTALL_BAZAAR"
log "INSTALL_POSTGRES         = $INSTALL_POSTGRES" 
log "INSTALL_MYSQL            = $INSTALL_MYSQL" 
log "INSTALL_ASCIIDOCTOR      = $INSTALL_ASCIIDOCTOR" 
log "---------------------------------------------" 

DEV_HOME="/home/$DEVELOPER_ID"



# ============================================================================
#                                                         PACKAGE REPOSITORIES
# ============================================================================

# ############################################## Add the Deadsnakes Repository
# // (This does not work for vanilla Debian, only for Ubuntu)
# // sudo apt-get update
# // # The software-properties-common package supports adding PPAs (Personal Package 
# // # Archive) repositories.
# // sudo apt-get -yq install software-properties-common 2>> $LOG_FILE
# // # The Deadsnakes PPA has newer releases (of python) than the default Debian 
# // # repositories
# // sudo add-apt-repository ppa:deadsnakes/ppa
# // sudo apt-get update

if [ "$INSTALL_POSTGRES" == "YES" ]; then
	log_step "Pointing apt to the PostgreSQL repository." 
	echo "deb http://apt.postgresql.org/pub/repos/apt/ precise-pgdg main" > /etc/apt/sources.list.d/pgdg.list
	wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
fi
log_step "Updating apt" 
sudo apt-get update 2>> $LOG_FILE
sudo apt-get -yq upgrade 2>> $LOG_FILE



# ============================================================================
#                                                            SOFTWARE INSTALLS
# ============================================================================

# ##############################################   VERSION CONTROL (Git, Mercury, and Bazaar)
log_step "Installing Git version-control" 
sudo apt-get -yq install git  2>> $LOG_FILE
GIT_VER=`git --version`

HG_VER="(not installed)"
if [ "$INSTALL_MERCURIAL" == "YES" ]; then
	log_step "Installing Mercurial version-control" 
    sudo apt-get -yq install mercurial 2>> $LOG_FILE
	HG_VER=`hg --version`
fi

BZR_VER="(not installed)"
if [ "$INSTALL_BAZAAR" == "YES" ]; then
	log_step "Installing Bazaar version-control" 
    sudo apt-get -yq install bzr 2>> $LOG_FILE
	BZR_VER=`bzr --version`
fi

# ##############################################   Python 3, Pip, Pytest, venv
PY3_VER=`python3 -c 'import sys; print(f"{sys.version_info[0]}.{sys.version_info[1]}.{sys.version_info[2]}")'`

if [ "$BUILD_PYTHON_FROM_SOURCE" == "NO" ]; then
	sudo apt-get -yq install python3 2>> $LOG_FILE
	sudo apt-get -yq install python3-pip 2>> $LOG_FILE
else if [ "$PY3_VER" != "$BUILD_PYTHON_FROM_SOURCE" ]; then
	log_step "Preparing to build Python $BUILD_PYTHON_FROM_SOURCE from source"
	sudo apt-get -yq install build-essential zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev libssl-dev libsqlite3-dev libreadline-dev libffi-dev curl libbz2-dev 2>> $LOG_FILE
	wget https://www.python.org/ftp/python/$BUILD_PYTHON_FROM_SOURCE/Python-$BUILD_PYTHON_FROM_SOURCE.tgz
	tar -xf Python-$BUILD_PYTHON_FROM_SOURCE.tgz
	log_step "Compiling Python"
	cd Python-$BUILD_PYTHON_FROM_SOURCE
	./configure --enable-optimizations
	make -j 2
	log_step "Installing as Python3"
	sudo make install # overwrites the python3 binary with python3.9
	# // sudo make altinstall # leaves python3 and just creates python3.9
else 
	log "Python $BUILD_PYTHON_FROM_SOURCE already installed. No need to build from source."
fi
fi

# This will install an older version of python3-venv than the version of python3 we just built, but it seems to work.
sudo apt-get -yq install python3-venv 2>> $LOG_FILE

pip3 install --upgrade pip 2>> $LOG_FILE
if [-n "$PYTHON_PACKAGES" ]; then
	log_step "Installing Python packages (system-wide): $PYTHON_PACKAGES"
	sudo -u $DEVELOPER_ID pip3 install $PYTHON_PACKAGES &>> $LOG_FILE
fi

PY3_VER=`python3 -c 'import sys; print(f"{sys.version_info[0]}.{sys.version_info[1]}.{sys.version_info[2]}")'`
PY2_VER=`python -c 'import sys; print("%s.%s.%s" % (sys.version_info[0],sys.version_info[1],sys.version_info[2]))'`
PIP_VER=`pip --version`

# ##############################################   MySQL
MYSQL_VER="(not installed)"

# ##############################################   Postgres
PG_VER="(not installed)"
if [ "$INSTALL_POSTGRES" == "YES" ]; then
	log_step "Installing PostgreSQL" 
	sudo apt-get -yq install postgresql postgresql-contrib 2>> $LOG_FILE
	log_step "Changing Postgre to trust mode (/etc/postgresql/main/pg_hba.conf)" 
	sed -i "s/local\s*all\s*all\s*peer/local all all trust/" /etc/postgresql/main/pg_hba.conf 2>> $LOG_FILE
	sudo /etc/init.d/postgresql restart 2>> $LOG_FILE
	log_step "Creating PostgreSQL user '$DEVELOPER_ID' as a superuser and an empty 'vagrant' database." 
	sudo -u postgres createuser --superuser $DEVELOPER_ID 2>> $LOG_FILE
	sudo -u postgres createdb --owner=$DEVELOPER_ID vagrant 2>> $LOG_FILE
fi

# ##############################################   AsciiDoctor
DOCTOR_VER="(not installed)"
if [ "$INSTALL_ASCIIDOCTOR" == "YES" ]; then
	log_step "Installing AsciiDoctor" 
	sudo apt-get -yq install asciidoctor 2>> $LOG_FILE
	DOCTOR_VER=`asciidoctor --version`
fi

# ##############################################   Misc. Tools
log_step "Installing misc. command lines tools (dos2unix, etc.)"
sudo apt-get -yq install dos2unix  2>> $LOG_FILE # converts line-endings
sudo apt-get -yq install htop      2>> $LOG_FILE # system stats
sudo apt-get -yq install ncdu      2>> $LOG_FILE # manages disk usage
sudo apt-get -yq install ufw       2>> $LOG_FILE # simplified firewall configuring



# ============================================================================
#                                                                SYSTEM CONFIG
# ============================================================================

# ##############################################   Time Zone

log_step "Setting time zone to $SYSTEM_TIMEZONE"
sudo timedatectl set-timezone $SYSTEM_TIMEZONE 2>> $LOG_FILE



# ============================================================================
#                                                       USER ACCOUNTS/SECURITY
# ============================================================================
log_step "Creating user account: $DEVELOPER_ID ($DEVELOPER_NAME) with default password of $DEVELOPER_ID" 
useradd -m -c "$DEVELOPER_NAME" -s /bin/bash -G sudo,vagrant -U $DEVELOPER_ID
echo "$DEVELOPER_ID:$DEVELOPER_ID" | chpasswd
sudo -u $DEVELOPER_ID mkdir -p $DEV_HOME/.ssh
sudo cp /home/vagrant/.ssh/authorized_keys $DEV_HOME/.ssh/authorized_keys
chown_dev $DEV_HOME/.ssh/authorized_keys



# ============================================================================
#                                                         USER-SPECIFIC CONFIG
# ============================================================================

# ##############################################   BASH Aliases
if [ -f "/vagrant/bash_aliases" ]; then
	if ! [ -f "/home/vagrant/.bash_aliases" ]; then
		log_step "Copying bash_aliases as /home/vagrant/.bash_aliases" 
		sudo cp /vagrant/bash_aliases /home/vagrant/.bash_aliases 2>> $LOG_FILE
		sudo chmod 644 /home/vagrant/.bash_aliases 2>> $LOG_FILE
	fi
	if ! [ -f "$DEV_HOME/.bash_aliases" ]; then
		log_step "Copying bash_aliases as $DEV_HOME/.bash_aliases" 
		sudo -u $DEVELOPER_ID cp /vagrant/bash_aliases $DEV_HOME/.bash_aliases 2>> $LOG_FILE
		sudo -u $DEVELOPER_ID chmod 644 $DEV_HOME/.bash_aliases 2>> $LOG_FILE
	fi
fi

# ##############################################   Version Control Configuration
log_step "Configuring Git (Version Control)"
echo "https://$GITHUB_USER_ID:$GITHUB_APP_TOKEN@github.com" > $DEV_HOME/.git-api
chown_dev $DEV_HOME/.git-api
sudo -u $DEVELOPER_ID git config --global user.name "$DEVELOPER_NAME" 2>> $LOG_FILE
sudo -u $DEVELOPER_ID git config --global user.email "$DEVELOPER_EMAIL" 2>> $LOG_FILE
sudo -u $DEVELOPER_ID git config --global --add credential.helper "store --file ~/.git-api" &>> $LOG_FILE

if [ "$INSTALL_MERCURIAL" == "YES" ]; then
	log_step "Configuring Mercurial (Version Control)"
	echo "[ui]" > $DEV_HOME/.hgrc
	echo "username=$DEVELOPER_NAME <$DEVELOPER_EMAIL>" >> $DEV_HOME/.hgrc
	chown_dev $DEV_HOME/.hgrc
fi

if [ "$INSTALL_BAZAAR" == "YES" ]; then
	log_step "Configuring Bazaar (Version Control)"
	sudo -u $DEVELOPER_ID bzr whoami "$DEVELOPER_NAME <$DEVELOPER_EMAIL>"
fi



# ============================================================================
#                                                            HEIGHTEN SECURITY
# ============================================================================

if [ "$SECURITY_LEVEL" == "HIGH" ]; then
	log_step "Heightening security..."
	source /vagrant/scripts_library/heighten_security.sh "$LOG_FILE" 
fi



# ============================================================================
#                                                                      CLEANUP
# ============================================================================

sudo apt-get autoremove 2>> $LOG_FILE

revert_to_interactive

log_header "RECAP"
log ""
log "Python 3 = $PY3_VER"  
log "Python 2 = $PY2_VER"  
log "Pip = $PIP_VER"  
log ""  
log "Git = $GIT_VER"  
sudo -u $DEVELOPER_ID git config -l &>> $LOG_FILE
log ""  
log "Mercurial = $HG_VER"  
log ""  
log "Bazaar = $BZR_VER"  
log ""  
log "Postgres = $PG_VER"  
log ""  
log "MySQL = $MYSQL_VER"  
log ""  
log "AsciiDoctor = $DOCTOR_VER"  
log ""
log "Firewall `sudo ufw status`"
log ""
log ""
log ""
