wget https://github.com/containerd/containerd/releases/download/v1.6.12/containerd-1.6.12-linux-amd64.tar.gz
tar xvf containerd-1.6.12-linux-amd64.tar.gz
systemctl stop containerd
cd bin
cp * /usr/bin/
systemctl start containerd

#apt remove --purge kubelet
#apt install -y kubelet=1.25.5-00
