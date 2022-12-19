[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://github.com/realcryptonight2/debian-install-scripts/blob/master/LICENSE.md)
# debian-install-scripts
These are the debian scripts I use.

# Install DirectAdmin command
To install DirectAdmin please run the following command:  
```
apt update &&
apt -y upgrade &&
apt -y install git &&
git clone https://github.com/realcryptonight/debian-install-scripts.git &&
cd debian-install-scripts/ &&
chmod 755 setup-directadmin.sh &&
./setup-directadmin.sh <Your directAdmin license here> <your admin username here>
```