az group create --name cks-resourcegroup --location eastus
az ssh config --resource-group cks-resourcegroup --file=~/.ssh/azuresshconfig
az vm create \
    --resource-group cks-resourcegroup \
    --name cks-master \
    --image UbuntuLTS \
    --generate-ssh-keys &

az vm create \
    --resource-group cks-resourcegroup \
    --name cks-worker \
    --image UbuntuLTS \
    --generate-ssh-keys &
