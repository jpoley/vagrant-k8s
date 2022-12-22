
kubectl create ns argo
wget https://github.com/argoproj/argo-workflows/releases/download/v3.3.10/install.yaml
mv install.yaml argo-workflow.yaml
kubectl apply -n argo -f argo-workflow.yaml

kubectl create namespace argo-events
wget https://raw.githubusercontent.com/argoproj/argo-events/stable/manifests/install.yaml
mv install.yaml argo-events.yaml
kubectl apply -f argo-events.yaml


wget https://raw.githubusercontent.com/argoproj/argo-events/stable/examples/eventbus/native.yaml
mv native.yaml eventbus.yaml
kubectl apply -n argo-events -f eventbus.yaml


kubectl create namespace argocd
wget https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
mv install.yaml argocd.yaml
kubectl apply -n argocd -f argocd.yaml

kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort"}}'
kubectl port-forward svc/argocd-server -n argocd 8080:443

# install argocd
#argocd login <ARGOCD_SERVER>
#argocd account update-password
#argocd cluster add
#argocd cluster add docker-for-desktop


