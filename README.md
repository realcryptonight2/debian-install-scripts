[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/realcryptonight2/debian-install-scripts/blob/master/LICENSE.md)
# debian-install-scripts
These are the debian scripts I use.

# Pre install requirements.
To use this install script you need to create a config.cnf file.
This config file will store your DirectAdmin license key and username.

First create a file and call it config.cnf
Then add the following to the config.cnf file:
```
# DirectAdmin settings
directadmin_setup_license_key="<your DirectAdmin License key here> (Required)"
directadmin_setup_admin_username="<your DirectAdmin admin username here> (Optional)"
directadmin_setup_headless_email="<the email that the login details should be send to (leave empty for login details on terminal)> (Optional)"
directadmin_custom_config_ns="<set to 1 to enable> (Optional)"
directadmin_custom_config_mysql="<set to 1 to enable> (Optional)"
directadmin_custom_config_ftp="<set to 1 to enable> (Optional)"
```
After that keep note of the file location as you wu=ill need to copy this file into the cloned repository.

# Install DirectAdmin command
To install DirectAdmin please run the following command(s):  
```
apt update &&
apt -y upgrade &&
apt -y install git &&
git clone https://github.com/realcryptonight/debian-install-scripts.git &&
cp ./config.cnf ./debian-install-scripts/
cd debian-install-scripts/ &&
git checkout dev-test &&
chmod 755 setup-directadmin.sh &&
./setup-directadmin.sh
```