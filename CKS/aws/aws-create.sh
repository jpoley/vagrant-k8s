aws ec2 import-key-pair --key-name=cks --public-key=$(cat ~/.ssh/id_rsa.pub|base64)
aws ec2 run-instances --image-id ami-00ddb0e5626798373 --instance-type t3.large --key-name=cks --count=2

