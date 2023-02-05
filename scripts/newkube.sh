curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt update -y
sudo apt -y install vim git curl wget kubelet=1.26.1-00 kubeadm=1.26.1-00 kubectl=1.26.1-00
sudo apt-mark hold kubelet kubeadm kubectl

#####################

sudo modprobe overlay
sudo modprobe br_netfilter
sudo tee /etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
sysctl --system

######################

cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# Setup required sysctl params, these persist across reboots.
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

# Apply sysctl params without reboot
sudo sysctl --system

#Install and configure containerd 
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt update -y
sudo apt install -y containerd.io
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml

#Start containerd
sudo systemctl restart containerd
sudo systemctl enable containerd

###################

sudo kubeadm config images pull --image-repository=registry.k8s.io --cri-socket unix:///run/containerd/containerd.sock --kubernetes-version v1.26.1


###################

sudo kubeadm init --apiserver-advertise-address="192.168.56.10" --apiserver-cert-extra-sans="192.168.56.10"  --kubernetes-version 1.26.1 --node-name k8s-master --pod-network-cidr=192.168.56.0/21 --cri-socket unix:///run/containerd/containerd.sock --image-repository=registry.k8s.io --v=6
#sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --upload-certs --kubernetes-version=v1.26.1 --control-plane-endpoint=74.220.27.73 --cri-socket unix:///run/containerd/containerd.sock

