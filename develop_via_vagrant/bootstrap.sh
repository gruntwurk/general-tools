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
SCRIPT_DIR="/scripts_library"

# ============================================================================
#                                                             Helper Functions
# ============================================================================

# Import the common helper functions
if [ -f $SCRIPT_DIR/helper_functions_debian.sh ]; then
	source $SCRIPT_DIR/helper_functions_debian.sh
else
	echo "$SCRIPT_DIR/helper_functions_debian.sh does not exist! Aborting." >> $LOG_FILE
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

debug
debug SYSTEM_TIMEZONE
debug DEVELOPER_ID
debug DEVELOPER_NAME
debug DEVELOPER_EMAIL
debug GITHUB_USER_ID
debug GITHUB_APP_TOKEN
debug SECURITY_LEVEL
debug
debug INSTALL_PIP2
debug PYTHON2_PACKAGES
debug INSTALL_PYGTK2
debug INSTALL_PYTHON3
debug BUILD_PYTHON3_FROM_SOURCE
debug PYTHON3_PACKAGES
debug
debug INSTALL_GIT
debug INSTALL_MERCURIAL
debug INSTALL_BAZAAR
debug
debug INSTALL_POSTGRES
debug INSTALL_MYSQL
debug
debug INSTALL_GNOME
debug INSTALL_ASCIIDOCTOR
debug

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
apt_update
apt_dist_upgrade


# ============================================================================
#                                                            SOFTWARE INSTALLS
# ============================================================================

# ##############################################   VERSION CONTROL (Git, Mercury, and Bazaar)
GIT_VER="(not installed)"
if [ "$INSTALL_GIT" == "YES" ]; then
	apt_install git "Git version-control"
	sudo apt-get -yq install git  2>> $LOG_FILE
	GIT_VER=`git --version`
fi

HG_VER="(not installed)"
if [ "$INSTALL_MERCURIAL" == "YES" ]; then
	apt_install mercurial "Mercurial version-control"
	HG_VER=`hg --version`
fi

BZR_VER="(not installed)"
if [ "$INSTALL_BAZAAR" == "YES" ]; then
	apt_install bzr "Bazaar version-control"
	BZR_VER=`bzr --version`
fi

GNOME_VER="(not installed)"
if [ "$INSTALL_GNOME" == "YES" ]; then
	apt_install gnome-core "The Gnome graphics package (no apps)"
	GNOME_VER=`gnome --version`
fi

# ##############################################   Python 2, Pip
# Python 2 is pre-installed (but not PIP2)
PY2_VER=`python -c 'import sys; print("%s.%s.%s" % (sys.version_info[0],sys.version_info[1],sys.version_info[2]))'`

PIP2_VER="(not installed)"
if [ "$INSTALL_PIP2" == "YES" ]; then
	wget https://bootstrap.pypa.io/pip/2.7/get-pip.py 2>> $LOG_FILE
	sudo python get-pip.py 2>> $LOG_FILE
	PIP2_VER=`pip2 --version`
fi

if [ -n "$PYTHON2_PACKAGES" ]; then
	log_step "Installing Python2 packages (system-wide): $PYTHON2_PACKAGES"
	sudo pip2 install $PYTHON2_PACKAGES &>> $LOG_FILE
fi

if [ "$INSTALL_PYGTK2" == "YES" ]; then
	mkdir ~/pygtk
	cd ~/pygtk
	wget http://archive.ubuntu.com/ubuntu/pool/universe/p/pygtk/python-gtk2_2.24.0-5.1ubuntu2_amd64.deb 2>> $LOG_FILE
	wget http://archive.ubuntu.com/ubuntu/pool/universe/p/pygtk/python-glade2_2.24.0–5.1ubuntu2_amd64.deb 2>> $LOG_FILE
	apt_install ./python-gtk2_2.24.0-5.1ubuntu2_amd64.deb "GTK support for Python 2"
	apt_install ./python-glade2_2.24.0-5.1ubuntu2_amd64.deb "GTK support for Python 2"
	sudo ldconfig
fi

# ##############################################   Python 3, Pip, venv
PY3_VER="(not installed)"
PIP3_VER="(not installed)"
if [ "$INSTALL_PYTHON3" == "YES" ]; then
	if [ "$BUILD_PYTHON3_FROM_SOURCE" == "NO" ]; then
		apt_install python3 "Python3"
		apt_install python3-pip "Python3 package installer"
	elif [ "$PY3_VER" != "$BUILD_PYTHON3_FROM_SOURCE" ]; then
		log_step "Preparing to build Python $BUILD_PYTHON3_FROM_SOURCE from source"
		sudo apt-get -yq install build-essential zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev libssl-dev libsqlite3-dev libreadline-dev libffi-dev curl libbz2-dev 2>> $LOG_FILE
		wget https://www.python.org/ftp/python/$BUILD_PYTHON3_FROM_SOURCE/Python-$BUILD_PYTHON3_FROM_SOURCE.tgz
		tar -xf Python-$BUILD_PYTHON3_FROM_SOURCE.tgz
		log_step "Compiling Python"
		cd Python-$BUILD_PYTHON3_FROM_SOURCE
		./configure --enable-optimizations
		make -j 2
		log_step "Installing as Python3"
		sudo make install # overwrites the python3 binary with python3.9
		# // sudo make altinstall # leaves python3 and just creates python3.9
	else
		log "Python $BUILD_PYTHON3_FROM_SOURCE already installed. No need to build from source."
	fi
	PY3_VER=`python3 -c 'import sys; print(f"{sys.version_info[0]}.{sys.version_info[1]}.{sys.version_info[2]}")'`

	pip3 install --upgrade pip 2>> $LOG_FILE
	PIP3_VER=`pip3 --version`

	# This will install an older version of python3-venv than the version of python3 we potentially just built, but it seems to work.
	apt_install python3-venv "Python3 Virtual Environments"

	if [ -n "$PYTHON3_PACKAGES" ]; then
		log_step "Installing Python3 packages (system-wide): $PYTHON3_PACKAGES"
		sudo pip3 install $PYTHON3_PACKAGES &>> $LOG_FILE
	fi
fi



# ##############################################   MySQL
MYSQL_VER="(not installed)"

# ##############################################   Postgres
PG_VER="(not installed)"
if [ "$INSTALL_POSTGRES" == "YES" ]; then
	log_step "Installing PostgreSQL" 
	apt_install postgresql "Postgres SQL server"
	apt_install postgresql-contrib "Postgres add-ons"
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
	apt_install asciidoctor "AsciiDoctor markup compiler"
	DOCTOR_VER=`asciidoctor --version`
fi

# ##############################################   Misc. Tools
log_step "Installing misc. command lines tools (dos2unix, etc.)"
apt_install dos2unix  "Command-line tool that converts line-endings"
apt_install htop      "Command-line tool that shows system stats"
apt_install ncdu      "Command-line tool to manage disk usage"
apt_install ufw       "Command-line tool for simplified firewall configuring"



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
if [ "$INSTALL_GIT" == "YES" ]; then
	log_step "Configuring Git (Version Control)"
	echo "https://$GITHUB_USER_ID:$GITHUB_APP_TOKEN@github.com" > $DEV_HOME/.git-api
	chown_dev $DEV_HOME/.git-api
	sudo -u $DEVELOPER_ID git config --global user.name "$DEVELOPER_NAME" 2>> $LOG_FILE
	sudo -u $DEVELOPER_ID git config --global user.email "$DEVELOPER_EMAIL" 2>> $LOG_FILE
	sudo -u $DEVELOPER_ID git config --global --add credential.helper "store --file ~/.git-api" &>> $LOG_FILE
fi

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

# ##############################################   Expose X11 Graphics via SSH

conf_change /etc/ssh/ssh_config ForwardAgent yes
conf_change /etc/ssh/ssh_config ForwardX11 yes
conf_change /etc/ssh/ssh_config ForwardX11Trusted yes
conf_change /etc/ssh/sshd_config X11Forwarding yes


# ============================================================================
#                                                            HEIGHTEN SECURITY
# ============================================================================

if [ "$SECURITY_LEVEL" == "HIGH" ]; then
	log_step "Heightening security..."
	source $SCRIPT_DIR/heighten_security_debian.sh "$LOG_FILE"
fi



# ============================================================================
#                                                                      CLEANUP
# ============================================================================

apt_autoremove

revert_to_interactive

log_header "RECAP"
log
log "Gnome     = $GNOME_VER"
log
log "Python 3  = $PY3_VER"
log "Pip 3     = $PIP3_VER"
log "Python 2  = $PY2_VER"
log "Pip 2     = $PIP2_VER"
log
log "Git       = $GIT_VER"
log $( sudo -u $DEVELOPER_ID git config -l )
log "Mercurial = $HG_VER"
log "Bazaar    = $BZR_VER"
log
log "Postgres  = $PG_VER"
log "MySQL     = $MYSQL_VER"
log
log "AsciiDoctor = $DOCTOR_VER"  
log
log "Firewall `sudo ufw status`"
log
log
log
