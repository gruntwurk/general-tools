#!/usr/bin/env bash

# ----------------------------------------------------------------------------
# Set up a Linux box (e.g. Raspberry Pi) to be a Nextcloud Server -- Part 1
# ----------------------------------------------------------------------------

# STATUS:        INCOMPLETE!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# PREREQUISITES: Use `install_webserver_debian.sh` to install MariaDB, Apache2, PHP
# TARGET OS:     Debian-Based Linux
# PARAMETERS:    (none)
# INSPIRATION:   
# AUTHOR:        polygot-jones -- 7/13/2021
# LINE ENDINGS:  Be sure this file is saved with Unix line-endings.
# IDEMPOTENT:    There is no harm is running this script multiple times.
# References:    

# ============================================================================
#                                                     CHOOSE YOUR OPTIONS HERE
# ============================================================================

MACHINE_NAME=cloud  # (or blank this out, to leave the computer name alone)

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
#                                                            INSTALL NEXTCLOUD
# ============================================================================

# ###################  Create a database for Nextcloud
cat > create_nextcloud.sql <<-EOF
	CREATE DATABASE nextclouddb;
	CREATE USER 'nextclouduser'@'localhost' IDENTIFIED BY 'bgordon';
	GRANT ALL PRIVILEGES ON nextclouddb.* TO 'nextclouduser'@'localhost';
	FLUSH PRIVILEGES;
EOF
sudo mysql -u root -p < create_nextcloud.sql

# ###################  Install the NextCloud web interface
cd /var/www/
sudo wget https://download.nextcloud.com/server/releases/latest.tar.bz2
sudo tar -xvf latest.tar.bz2
sudo mkdir -p /var/www/nextcloud/data
sudo chown -R www-data:www-data /var/www/nextcloud/
sudo chmod 750 /var/www/nextcloud/data
cat > /etc/apache2/sites-available/nextcloud.conf <<-EOF
	Alias /nextcloud "/var/www/nextcloud/"
	<Directory /var/www/nextcloud/>
		Require all granted
		AllowOverride All
		Options FollowSymLinks MultiViews
		<IfModule mod_dav.c>
			Dav off
		</IfModule>
	</Directory>
EOF
sudo a2ensite nextcloud.conf
sudo systemctl reload apache2

# ----------------------------------------------------------------------------
# ??? Does Nextcloud need to be manually configured (via the web interface) 
# at this point? Or, can it wait until the end?
# ----------------------------------------------------------------------------

# Move the nextcloud data out of /var/www to just /var (to separate it from the static web interface code)
sudo mkdir -p /var/nextcloud
sudo mv -v /var/www/nextcloud/data /var/nextcloud/data
sudo chown -R www-data:www-data /var/nextcloud/data
conf_change /var/www/nextcloud/config/config.php ??? "/var/nextcloud/data"

# Change PHP's default limits on upload sizes
conf_change /etc/php/apache2/php.ini post_max_size "1024M"
conf_change /etc/php/apache2/php.ini upload_max_filesize "1024M"


# ============================================================================
#                                                                      CLEANUP
# ============================================================================

sudo service apache2 restart

# determine the RPi's IP address
show "The NextCloud configuration page is: https://$( hostname )/nextcloud ($( hostname -I ))"

