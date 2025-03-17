#!/bin/bash
# SummitEthic EC2 Instance Initialization Script
# Environment: ${environment}
# Region: ${region}

set -e

# Configure system hostname
hostnamectl set-hostname ${hostname}

# Update system packages
apt-get update
apt-get upgrade -y

# Install required packages
apt-get install -y apt-transport-https ca-certificates curl software-properties-common python3 python3-pip

# Set up Docker repository
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/download/v2.14.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

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

# Install AWS CLI
pip3 install awscli

# Install CloudWatch Agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i amazon-cloudwatch-agent.deb
systemctl enable amazon-cloudwatch-agent
systemctl start amazon-cloudwatch-agent

# Configure CloudWatch Agent
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<EOF
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "cwagent"
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/syslog",
            "log_group_name": "system-logs",
            "log_stream_name": "{hostname}-syslog"
          },
          {
            "file_path": "/var/log/auth.log",
            "log_group_name": "security-logs",
            "log_stream_name": "{hostname}-auth"
          }
        ]
      }
    }
  },
  "metrics": {
    "append_dimensions": {
      "InstanceId": "\${aws:InstanceId}"
    },
    "metrics_collected": {
      "disk": {
        "measurement": [
          "used_percent"
        ],
        "resources": [
          "*"
        ]
      },
      "mem": {
        "measurement": [
          "mem_used_percent"
        ]
      },
      "swap": {
        "measurement": [
          "swap_used_percent"
        ]
      }
    }
  }
}
EOF

# Apply CloudWatch Agent configuration
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

# Configure system time zone
timedatectl set-timezone UTC

# Set up Node Exporter for Prometheus
useradd --no-create-home --shell /bin/false node_exporter
wget https://github.com/prometheus/node_exporter/releases/download/v1.5.0/node_exporter-1.5.0.linux-amd64.tar.gz
tar xvfz node_exporter-1.5.0.linux-amd64.tar.gz
cp node_exporter-1.5.0.linux-amd64/node_exporter /usr/local/bin/
chown node_exporter:node_exporter /usr/local/bin/node_exporter

cat > /etc/systemd/system/node_exporter.service <<EOF
[Unit]
Description=Node Exporter
After=network.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable node_exporter
systemctl start node_exporter

# Configure system limits for application use
cat > /etc/security/limits.d/summitethic.conf <<EOF
* soft nofile 65536
* hard nofile 65536
* soft nproc 4096
* hard nproc 4096
EOF

# Configure kernel parameters for performance and security
cat > /etc/sysctl.d/99-summitethic.conf <<EOF
# Increase system file descriptor limit
fs.file-max = 65536

# Increase TCP max buffer size
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216

# Increase Linux autotuning TCP buffer limits
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216

# Enable TCP fastopen
net.ipv4.tcp_fastopen = 3

# Protect against TCP time-wait assassination
net.ipv4.tcp_rfc1337 = 1

# Protect against SYN flood attacks
net.ipv4.tcp_syncookies = 1

# Ignore ICMP broadcasts
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Disable source routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0

# Enable reverse path filtering
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Log martian packets
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
EOF

sysctl --system

# Set up EC2 tags as environment variables
mkdir -p /etc/summitethic
cat > /etc/summitethic/environment <<EOF
ENVIRONMENT=${environment}
REGION=${region}
HOSTNAME=${hostname}
EOF

# Ethical resource management - create fair-share limits
mkdir -p /etc/summitethic/resources
cat > /etc/summitethic/resources/limits.conf <<EOF
# SummitEthic Ethical Resource Limits
# These limits ensure fair resource distribution

# Default resource limits (50% of system)
DEFAULT_CPU_LIMIT=50
DEFAULT_MEMORY_LIMIT=50
DEFAULT_IO_WEIGHT=100

# Critical services may use up to 80% in emergency situations
CRITICAL_CPU_LIMIT=80
CRITICAL_MEMORY_LIMIT=80
CRITICAL_IO_WEIGHT=500

# Background services are limited to 30%
BACKGROUND_CPU_LIMIT=30
BACKGROUND_MEMORY_LIMIT=30
BACKGROUND_IO_WEIGHT=50
EOF

# Final setup message
echo "SummitEthic infrastructure node setup completed successfully" | tee /var/log/summitethic-setup.log

# Signal successful completion
touch /var/lib/cloud/instance/success