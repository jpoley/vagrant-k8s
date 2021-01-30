MY_IP=$(curl http://ipinfo.io/ip)
gcloud compute firewall-rules create nodeports --allow tcp:30000-40000 --source-ranges="$MY_IP/32"

