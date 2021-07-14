#!/usr/bin/env bash

# ----------------------------------------------------------------------------
#     Configure a Debian-based Linux Box (e.g. a Raspberry Pi) to be a 
#
#                           WEB SERVER (Apache) 
#
#                        backed by PHP over MariaDB
# ----------------------------------------------------------------------------

# PARAMETERS:   (none)
# AUTHOR:       polygot-jones -- 7/8/2021
# LINE ENDINGS: Be sure this file is saved with Unix line-endings.
# IDEMPOTENT?   No. Only run this once.
# References:   https://www.raspberrypi.org/documentation/remote-access/web-server/apache.md


# ============================================================================
#                                                     CHOOSE YOUR OPTIONS HERE
# ============================================================================
SSL_CERT_INFO="/C=US/ST=MyState/L=MyLocality/O=MyCompanyName/CN=MyDomainName"

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
sudo apt-get -y upgrade

apt_install curl "Command-line tool for making http requests"
apt_install ca-certificates "Certificate authorities for checking for the authenticity of SSL connections"
apt_install apt-transport-https "Adds https protocol support to the APT package manager"
# // apt_install software-properties-common "Part of extending the APT package manager to allow for custom repositories"
# // apt_install dirmngr "A server for managing and downloading OpenPGP and X.509 certificates"
# // sudo reboot

# ============================================================================
#                                                       INSTALL MARIADB SERVER 
# ============================================================================

# Download and run the script that MariaDB provides for pointing APT to their special package repository
curl -LsS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | sudo bash

apt_install "mariadb-server mariadb-client mariadb-backup" "MariaDB is a fork of MySQL."

# ============================================================================
#                                                        INSTALL APACHE SERVER
# ============================================================================

apt_install apache2 "Web server"


# ============================================================================
#                                                                   SET UP SSL 
# ============================================================================

save_backup /etc/apache2/sites-available/default-ssl.conf

# Use a self-signed certificate (-x509) w/o passphrase (-nodes)
sudo mkdir -p /etc/apache2/ssl
sudo openssl req -x509 -nodes -days 365 -newkey rsa:4096 \
  -keyout /etc/apache2/ssl/apache.key \
  -out /etc/apache2/ssl/apache.crt \
  -subj "$SSL_CERT_INFO" 
sudo a2enmod ssl
# TODO use the helper functions here
sudo sed -r -e "s%/etc/ssl/certs/ssl-cert-snakeoil.pem%/etc/apache2/ssl/apache.crt%" \
  -ibak /etc/apache2/sites-available/default-ssl.conf
sudo sed -r -e "s%/etc/ssl/private/ssl-cert-snakeoil.key%/etc/apache2/ssl/apache.key%" \
  -ibak /etc/apache2/sites-available/default-ssl.conf
sudo a2ensite default-ssl.conf
sudo service apache2 restart

# ============================================================================
#                                                   REDIRECT ALL HTTP TO HTTPS
# ============================================================================

sudo cat > /etc/apache2/sites-available/000-default.conf <<-EOF
<VirtualHost *:80>
	ServerAdmin example@example
	RewriteEngine On
	RewriteCond %{HTTPS} off
	RewriteRule ^(.*)$ https://%{HTTP_HOST}$1 [R=301,L]
</VirtualHost>
EOF
  
sudo a2enmod rewrite
sudo service apache2 restart



# ============================================================================
#                                                                  INSTALL PHP
# ============================================================================

apt_install php "PHP itself"
apt_install libapache2-mod-php "The Apache module that supports serving PHP pages"
apt_install php-mysql "The MySQL connector for PHP"
apt_install php-smbclient "Allows PHP to fetch files via SAMBA"
apt_install php-mbstring "Multi-byte string support for PHP"

# Create a test page
cd /var/www/html
sudo rm index.html
echo "<?php echo "hello world. It is"; echo date('Y-m-d H:i:s'); phpinfo() ?>" > index.php

sudo service apache2 restart 


show "Try browsing to http://$( hostname -I )"

