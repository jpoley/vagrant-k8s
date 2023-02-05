
#FILE=/etc/containerd/config.toml
#if test -f "$FILE"; then
#    echo "$FILE exists."
#    sudo rm -f $FILE
#else
#	ls -la /etc/containerd
#fi

sudo systemctl restart containerd
