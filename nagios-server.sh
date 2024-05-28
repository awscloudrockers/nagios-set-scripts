#!/bin/bash

# Variables
NAGIOS_USER="nagios"
NAGIOS_DIR="/root/nagios"
NRPE_VERSION="4.0.2"
REMOTE_LINUX_IP="5.175.142.66" # Replace with your remote host IP
HOST_NAME="tecmint"
HOST_ALIAS="CentOS 6"
NAGIOS_CFG_DIR="/usr/local/nagios/etc"

# Step 1: Install NRPE Plugin in Nagios
echo "Installing NRPE plugin in Nagios Monitoring Server..."

# Create Nagios directory if it does not exist
mkdir -p $NAGIOS_DIR
cd $NAGIOS_DIR

# Download NRPE
wget https://github.com/NagiosEnterprises/nrpe/releases/download/nrpe-${NRPE_VERSION}/nrpe-${NRPE_VERSION}.tar.gz

# Unpack NRPE source code
tar xzf nrpe-${NRPE_VERSION}.tar.gz
cd nrpe-${NRPE_VERSION}

# Compile and install NRPE addon
./configure
make all
make install-plugin
make install-daemon
make install-init

# Step 2: Verify NRPE Daemon Remotely
echo "Verifying NRPE daemon remotely..."
/usr/local/nagios/libexec/check_nrpe -H $REMOTE_LINUX_IP

# Step 3: Add Remote Linux Host to Nagios Monitoring Server
echo "Adding remote Linux host to Nagios Monitoring Server..."

# Create hosts and services configuration files
cd $NAGIOS_CFG_DIR
touch hosts.cfg services.cfg

# Add the new files to the main Nagios configuration file
if ! grep -q "cfg_file=$NAGIOS_CFG_DIR/hosts.cfg" $NAGIOS_CFG_DIR/nagios.cfg; then
  echo "cfg_file=$NAGIOS_CFG_DIR/hosts.cfg" >> $NAGIOS_CFG_DIR/nagios.cfg
fi

if ! grep -q "cfg_file=$NAGIOS_CFG_DIR/services.cfg" $NAGIOS_CFG_DIR/nagios.cfg; then
  echo "cfg_file=$NAGIOS_CFG_DIR/services.cfg" >> $NAGIOS_CFG_DIR/nagios.cfg
fi

# Step 4: Configure Nagios Host and Services File
echo "Configuring Nagios host and services file..."

# Configure hosts.cfg
cat <<EOL > $NAGIOS_CFG_DIR/hosts.cfg
define host{
  name                            linux-box
  use                             generic-host
  check_period                    24x7
  check_interval                  5
  retry_interval                  1
  max_check_attempts              10
  check_command                   check-host-alive
  notification_period             24x7
  notification_interval           30
  notification_options            d,r
  contact_groups                  admins
  register                        0
}

define host{
  use                             linux-box
  host_name                       $HOST_NAME
  alias                           $HOST_ALIAS
  address                         $REMOTE_LINUX_IP
}
EOL

# Configure services.cfg
cat <<EOL > $NAGIOS_CFG_DIR/services.cfg
define service{
  use                     generic-service
  host_name               $HOST_NAME
  service_description     CPU Load
  check_command           check_nrpe!check_load
}

define service{
  use                     generic-service
  host_name               $HOST_NAME
  service_description     Total Processes
  check_command           check_nrpe!check_total_procs
}

define service{
  use                     generic-service
  host_name               $HOST_NAME
  service_description     Current Users
  check_command           check_nrpe!check_users
}

define service{
  use                     generic-service
  host_name               $HOST_NAME
  service_description     SSH Monitoring
  check_command           check_nrpe!check_ssh
}

define service{
  use                     generic-service
  host_name               $HOST_NAME
  service_description     FTP Monitoring
  check_command           check_nrpe!check_ftp
}
EOL

# Step 5: Configuring NRPE Command Definition
echo "Configuring NRPE command definition..."

# Add NRPE command definition in commands.cfg
cat <<EOL >> $NAGIOS_CFG_DIR/objects/commands.cfg
###############################################################################
# NRPE CHECK COMMAND
#
# Command to use NRPE to check remote host systems
###############################################################################

define command{
  command_name check_nrpe
  command_line \$USER1\$/check_nrpe -H \$HOSTADDRESS\$ -c \$ARG1\$
}
EOL

# Step 6: Verify Nagios Configuration and Restart
echo "Verifying Nagios configuration..."
/usr/local/nagios/bin/nagios -v $NAGIOS_CFG_DIR/nagios.cfg

echo "Restarting Nagios..."
systemctl restart nagios

echo "NRPE installation and configuration on Nagios Monitoring Server completed successfully."
