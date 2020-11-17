
kubectl create ns argo
kubectl apply -n argo -f argo-workflow.yaml
# https://raw.githubusercontent.com/argoproj/argo/stable/manifests/namespace-install.yaml

kubectl create namespace argo-events
kubectl apply -f argo-events.yaml
# https://raw.githubusercontent.com/argoproj/argo-events/stable/manifests/install.yaml
kubectl apply -n argo-events -f eventbus.yaml
# https://raw.githubusercontent.com/argoproj/argo-events/stable/examples/eventbus/native.yaml

kubectl create namespace argocd
kubectl apply -n argocd -f argocd.yaml
# https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
kubectl port-forward svc/argocd-server -n argocd 8080:443

# install argocd
#argocd login <ARGOCD_SERVER>
#argocd account update-password
#argocd cluster add
#argocd cluster add docker-for-desktop


