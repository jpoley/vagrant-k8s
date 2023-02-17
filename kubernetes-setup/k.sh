kubeadm init --apiserver-advertise-address="192.168.56.10" --apiserver-cert-extra-sans="192.168.56.10"  --kubernetes-version 1.26.0 --node-name k8s-master --pod-network-cidr=192.168.56.0/21 --v=6
