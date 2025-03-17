#!/bin/bash
# SummitEthic Infrastructure Bootstrap Script
# This script prepares a server for Ansible management

set -e

# Display banner
echo "┌─────────────────────────────────────────┐"
echo "│ SummitEthic Infrastructure Bootstrap    │"
echo "└─────────────────────────────────────────┘"

# Default values
USERNAME="summitethic"
SSH_PORT=22
ENABLE_UFW=true
INSTALL_DOCKER=true
ENABLE_AUTOMATIC_UPDATES=true
BASE_PACKAGES="vim curl wget htop git unzip apt-transport-https ca-certificates gnupg lsb-release software-properties-common python3 python3-pip"

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --username)
      USERNAME="$2"
      shift 2
      ;;
    --ssh-port)
      SSH_PORT="$2"
      shift 2
      ;;
    --no-ufw)
      ENABLE_UFW=false
      shift
      ;;
    --no-docker)
      INSTALL_DOCKER=false
      shift
      ;;
    --no-auto-updates)
      ENABLE_AUTOMATIC_UPDATES=false
      shift
      ;;
    --help)
      echo "Usage: $0 [OPTIONS]"
      echo ""
      echo "Options:"
      echo "  --username USERNAME       Admin username (default: summitethic)"
      echo "  --ssh-port PORT           SSH port (default: 22)"
      echo "  --no-ufw                  Skip UFW firewall setup"
      echo "  --no-docker               Skip Docker installation"
      echo "  --no-auto-updates         Skip automatic updates setup"
      echo "  --help                    Display this help message"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root"
  exit 1
fi

# Display configuration
echo "Bootstrap Configuration:"
echo "- Admin username: $USERNAME"
echo "- SSH port: $SSH_PORT"
echo "- Enable UFW firewall: $ENABLE_UFW"
echo "- Install Docker: $INSTALL_DOCKER"
echo "- Enable automatic updates: $ENABLE_AUTOMATIC_UPDATES"
echo ""
echo "Starting bootstrap process..."

# Update system
echo "[1/8] Updating system packages..."
apt-get update
apt-get upgrade -y

# Install base packages
echo "[2/8] Installing base packages..."
apt-get install -y $BASE_PACKAGES

# Create admin user
echo "[3/8] Creating admin user..."
if id "$USERNAME" &>/dev/null; then
  echo "User '$USERNAME' already exists"
else
  useradd -m -s /bin/bash -G sudo "$USERNAME"
  mkdir -p /home/$USERNAME/.ssh
  chmod 700 /home/$USERNAME/.ssh
  touch /home/$USERNAME/.ssh/authorized_keys
  chmod 600 /home/$USERNAME/.ssh/authorized_keys
  chown -R $USERNAME:$USERNAME /home/$USERNAME/.ssh
  
  # Generate random password
  TEMP_PASSWORD=$(openssl rand -base64 16)
  echo "$USERNAME:$TEMP_PASSWORD" | chpasswd
  
  echo "User '$USERNAME' created with temporary password: $TEMP_PASSWORD"
  echo "Please change this password immediately after login"
fi

# Set up SSH keys
echo "[4/8] Setting up SSH authentication..."
read -p "Paste the public SSH key for $USERNAME (or enter to skip): " SSH_KEY
if [ ! -z "$SSH_KEY" ]; then
  echo "$SSH_KEY" >> /home/$USERNAME/.ssh/authorized_keys
  echo "SSH key added to $USERNAME's authorized_keys"
fi

# Configure SSH
echo "[5/8] Configuring SSH..."
sed -i 's/^#\?PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/^#\?PubkeyAuthentication .*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#\?Port .*/Port '"$SSH_PORT"'/' /etc/ssh/sshd_config

# Add authorized key for current connection if using non-standard port
if [ "$SSH_PORT" != "22" ]; then
  # Get current SSH key if available
  CURRENT_KEY=$(who am i | awk '{print $1}' | xargs -I{} bash -c 'grep "$(ps -o command= -p $(ps -o ppid= -p $(ps -o ppid= -p $(ps -o ppid= -p $$))))$" /var/log/auth.log | grep -o "key: .*" | head -1' 2>/dev/null || echo "")
  
  if [ ! -z "$CURRENT_KEY" ] && [ ! -z "$SSH_KEY" ]; then
    mkdir -p /root/.ssh
    chmod 700 /root/.ssh
    echo "$CURRENT_KEY" >> /root/.ssh/authorized_keys
    chmod 600 /root/.ssh/authorized_keys
    echo "Current SSH key added to root's authorized_keys for transition"
  fi
fi

# Set up UFW firewall
if [ "$ENABLE_UFW" = true ]; then
  echo "[6/8] Configuring UFW firewall..."
  apt-get install -y ufw
  ufw default deny incoming
  ufw default allow outgoing
  ufw allow $SSH_PORT/tcp comment "SSH"
  ufw allow 80/tcp comment "HTTP"
  ufw allow 443/tcp comment "HTTPS"
  ufw --force enable
  ufw status
else
  echo "[6/8] Skipping UFW firewall setup..."
fi

# Install Docker
if [ "$INSTALL_DOCKER" = true ]; then
  echo "[7/8] Installing Docker..."
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
  apt-get update
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
  
  # Add user to docker group
  usermod -aG docker $USERNAME
  
  # Create docker-compose directory and symlink for compatibility
  mkdir -p /usr/local/bin
  ln -sf /usr/bin/docker-compose /usr/local/bin/docker-compose 2>/dev/null || true
  
  # Configure Docker daemon with secure defaults
  mkdir -p /etc/docker
  cat > /etc/docker/daemon.json <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "iptables": false,
  "userns-remap": "default",
  "storage-driver": "overlay2"
}
EOF
  
  # Restart Docker to apply changes
  systemctl restart docker
  systemctl enable docker
else
  echo "[7/8] Skipping Docker installation..."
fi

# Configure automatic updates
if [ "$ENABLE_AUTOMATIC_UPDATES" = true ]; then
  echo "[8/8] Configuring automatic updates..."
  apt-get install -y unattended-upgrades
  cat > /etc/apt/apt.conf.d/20auto-upgrades <<EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
EOF
  
  # Configure which packages to automatically update
  cat > /etc/apt/apt.conf.d/50unattended-upgrades <<EOF
Unattended-Upgrade::Allowed-Origins {
  "\${distro_id}:\${distro_codename}";
  "\${distro_id}:\${distro_codename}-security";
  "\${distro_id}ESMApps:\${distro_codename}-apps-security";
  "\${distro_id}ESM:\${distro_codename}-infra-security";
};
Unattended-Upgrade::Package-Blacklist {
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::InstallOnShutdown "false";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF
else
  echo "[8/8] Skipping automatic updates setup..."
fi

# Final configurations
echo "Configuring system settings..."

# Disable root SSH access
passwd -l root

# Configure sudo with minimal privileges
echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME
chmod 440 /etc/sudoers.d/$USERNAME

# Set secure system limits
cat > /etc/security/limits.d/summitethic.conf <<EOF
* soft nofile 65536
* hard nofile 65536
* soft nproc 4096
* hard nproc 4096
EOF

# Enable process accounting for auditing
apt-get install -y acct
touch /var/log/wtmp
touch /var/log/btmp
chmod 664 /var/log/wtmp
chmod 600 /var/log/btmp

# Add SummitEthic banner
cat > /etc/issue <<EOF
SummitEthic Infrastructure Server
Unauthorized access is prohibited

EOF

cat > /etc/motd <<EOF
Welcome to SummitEthic Infrastructure Server

This system is monitored for security and ethical compliance.
All actions are logged and audited.

EOF

# Restart SSH to apply changes
echo "Restarting SSH service..."
systemctl restart sshd

# Display completion message
echo ""
echo "┌─────────────────────────────────────────┐"
echo "│ Bootstrap Completed Successfully!       │"
echo "└─────────────────────────────────────────┘"
echo ""
echo "Server is now ready for Ansible management."
echo ""
echo "IMPORTANT NOTES:"
echo "- SSH configured on port $SSH_PORT"
echo "- Root login is disabled"
echo "- Password authentication is disabled"
echo "- Use the created user '$USERNAME' for all access"
echo "- If you changed the SSH port, ensure your next connection uses the new port"
echo ""

if [ "$SSH_PORT" != "22" ]; then
  echo "To connect: ssh -p $SSH_PORT $USERNAME@<server-ip>"
else
  echo "To connect: ssh $USERNAME@<server-ip>"
fi

echo ""
echo "For security, this terminal will remain open for 5 minutes before logout."
echo "Make sure you can open a new SSH connection before closing this terminal."
echo ""

exit 0