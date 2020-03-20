ISTIO_VERSION=istio-1.5.0

curl -L https://git.io/getLatestIstio | sh -
cd $ISTIO_VERSIONi
export PATH=$PWD/bin:$PATH
cd ..
kubectl apply -f $ISTIO_VERSION/install/kubernetes/helm/istio/templates/crds.yaml
