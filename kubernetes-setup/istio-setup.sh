curl -L https://git.io/getLatestIstio | sh -
cd istio-1.0.6
export PATH=$PWD/bin:$PATH
cd ..
kubectl apply -f istio-1.0.6/install/kubernetes/helm/istio/templates/crds.yaml
