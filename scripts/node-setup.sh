#!/bin/bash
set -e

echo "=== Setting up Kubernetes Worker Node ==="

# Install packages that allow apt to be used over HTTPS
echo "Installing prerequisites..."
apt-get update
apt-get install -y apt-transport-https ca-certificates curl gnupg-agent software-properties-common

# Add Docker GPG key and repository
echo "Adding Docker repository..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu noble stable"

# Install Docker and containerd
echo "Installing Docker and containerd..."
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io

# Add vagrant user to docker group
usermod -aG docker vagrant

# Start and enable Docker
systemctl start docker
systemctl enable docker

# Remove swap from /etc/fstab
echo "Disabling swap..."
sed -i '/\sswap\s/ s/^\(.*\)$/#\1/g' /etc/fstab
swapoff -a

# Add Kubernetes GPG key and repository
echo "Adding Kubernetes repository..."
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.34/deb/Release.key | apt-key add -
echo "deb https://pkgs.k8s.io/core:/stable:/v1.34/deb/ /" > /etc/apt/sources.list.d/kubernetes.list

# Install Kubernetes binaries
echo "Installing Kubernetes binaries..."
apt-get update
apt-get install -y kubelet=1.34.1-1.1 kubeadm=1.34.1-1.1 kubectl=1.34.1-1.1
apt-mark hold kubelet kubeadm kubectl

# Remove default containerd config and restart
echo "Configuring containerd..."
rm -f /etc/containerd/config.toml
systemctl restart containerd

# Wait for join command to be available
echo "Waiting for join command from master..."
while [ ! -f /vagrant/join-command ]; do
  sleep 5
done

# Join the cluster
echo "Joining the cluster..."
bash /vagrant/join-command

echo "=== Worker node setup complete ==="
