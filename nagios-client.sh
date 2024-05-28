#!/bin/bash

# Variables
NAGIOS_USER="nagios"
NAGIOS_DIR="/root/nagios"
NAGIOS_PLUGINS_VERSION="2.3.3"
NRPE_VERSION="4.0.2"
NAGIOS_SERVER_IP="192.168.102"

# Step 1: Install Required Dependencies
echo "Installing required dependencies..."
yum install -y gcc glibc glibc-common gd gd-devel make net-snmp openssl-devel tar wget

# Step 2: Create Nagios User
echo "Creating Nagios user..."
useradd $NAGIOS_USER
passwd $NAGIOS_USER

# Step 3: Install the Nagios Plugins
echo "Installing Nagios plugins..."
mkdir -p $NAGIOS_DIR
cd $NAGIOS_DIR
wget https://nagios-plugins.org/download/nagios-plugins-${NAGIOS_PLUGINS_VERSION}.tar.gz

# Step 4: Extract Nagios Plugins
echo "Extracting Nagios plugins..."
tar -xvf nagios-plugins-${NAGIOS_PLUGINS_VERSION}.tar.gz

# Step 5: Compile and Install Nagios Plugins
echo "Compiling and installing Nagios plugins..."
cd nagios-plugins-${NAGIOS_PLUGINS_VERSION}
./configure
make
make install

# Set permissions
chown $NAGIOS_USER.$NAGIOS_USER /usr/local/nagios
chown -R $NAGIOS_USER.$NAGIOS_USER /usr/local/nagios/libexec

# Step 6: Installing NRPE Plugin
echo "Installing NRPE plugin..."
cd $NAGIOS_DIR
wget https://github.com/NagiosEnterprises/nrpe/releases/download/nrpe-${NRPE_VERSION}/nrpe-${NRPE_VERSION}.tar.gz

# Unpack NRPE source code
tar xzf nrpe-${NRPE_VERSION}.tar.gz
cd nrpe-${NRPE_VERSION}

# Compile and install NRPE addon
./configure --disable-ssl
make all
make install-plugin
make install-daemon
make install-config

# Install NRPE daemon under systemd as a service
make install-init

# Step 7: Configuring NRPE Plugin
echo "Configuring NRPE plugin..."
sed -i "s/allowed_hosts=127.0.0.1/allowed_hosts=127.0.0.1,${NAGIOS_SERVER_IP}/" /usr/local/nagios/etc/nrpe.cfg

# Enable and restart NRPE service
systemctl enable nrpe
systemctl restart nrpe

# Step 8: Open NRPE Port in Firewall
echo "Opening NRPE port in firewall..."
firewall-cmd --zone=public --add-port=5666/tcp
firewall-cmd --zone=public --add-port=5666/tcp --permanent

# Step 9: Verify NRPE Daemon Locally
echo "Verifying NRPE daemon locally..."
netstat -at | grep nrpe
netstat -na | grep "5666"

# Check NRPE version
/usr/local/nagios/libexec/check_nrpe -H 127.0.0.1

# Step 10: Customize NRPE Commands
echo "Customizing NRPE commands..."
NRPE_COMMANDS=("check_users" "check_load" "check_hda1" "check_total_procs" "check_zombie_procs")
for command in "${NRPE_COMMANDS[@]}"
do
  /usr/local/nagios/libexec/check_nrpe -H 127.0.0.1 -c $command
done

echo "NRPE installation and configuration completed successfully."
