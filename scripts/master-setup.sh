#!/bin/bash
set -e

echo "=== Setting up Kubernetes Master Node ==="

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

# Initialize Kubernetes cluster
echo "Initializing Kubernetes cluster..."
kubeadm init \
  --apiserver-advertise-address="192.168.56.10" \
  --apiserver-cert-extra-sans="192.168.56.10" \
  --kubernetes-version 1.34.1 \
  --node-name k8s-cp \
  --pod-network-cidr=192.168.56.0/21 \
  --image-repository=registry.k8s.io \
  --v=6

# Setup kubeconfig for vagrant user
echo "Setting up kubeconfig..."
mkdir -p /home/vagrant/.kube
cp -i /etc/kubernetes/admin.conf /home/vagrant/.kube/config
chown -R vagrant:vagrant /home/vagrant/.kube

# Wait for API server to be fully ready
echo "Waiting for API server to be ready..."
sleep 10
until su - vagrant -c "kubectl get nodes" &> /dev/null; do
  echo "Waiting for API server..."
  sleep 5
done

# Install Calico network plugin
echo "Installing Calico network plugin..."
su - vagrant -c "kubectl create -f /home/vagrant/kubernetes-setup/tigera-operator.yaml"
sleep 5
su - vagrant -c "kubectl create -f /home/vagrant/kubernetes-setup/custom-resources.yaml"

# Generate join command
echo "Generating join command for worker nodes..."
kubeadm token create --print-join-command > /vagrant/join-command
chmod +x /vagrant/join-command

echo "=== Master node setup complete ==="
