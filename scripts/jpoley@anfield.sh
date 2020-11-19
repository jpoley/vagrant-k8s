kubectl taint nodes $(hostname) node-role.kubernetes.io/master:NoSchedule
