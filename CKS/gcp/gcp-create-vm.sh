gcloud compute instances create $1 --zone=us-east1-c \
--machine-type=e2-medium \
--image=ubuntu-2004-focal-v20221213 \
--image-project=ubuntu-os-cloud \
--boot-disk-size=50GB
