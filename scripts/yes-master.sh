kubectl taint nodes $(hostname) node-role.kubernetes.io/master:NoSchedule-
kubectl taint nodes $(hostname) node-role.kubernetes.io/control-plane:NoSchedule-
