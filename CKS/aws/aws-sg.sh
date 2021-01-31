echo "CURL"
MY_IP=$(curl http://ipinfo.io/ip)
echo "DELETE SG"
MY_VPC=$(aws ec2 describe-vpcs --filters Name=isDefault,Values=true | jq -r '.[][].VpcId')
aws ec2 delete-security-group --group-name=cks-sg
echo "CREATE SG"
export MY_SG=$(aws ec2 create-security-group --group-name=cks-sg --vpc-id=$MY_VPC --description=cks| jq -r '.GroupId')
echo $MY_IP $MY_SG $MY_VPC

MY_SG=$(aws ec2 describe-security-groups --group-id $MY_SG --group-names=cks-sg| jq -r '.[][].GroupId')
export SYNTAX="IpProtocol=tcp,FromPort=30000,ToPort=40000,IpRanges=[{CidrIp="$MY_IP"/32}]"
export SSH="IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges=[{CidrIp="$MY_IP"/32}]"
export HTTP="IpProtocol=tcp,FromPort=80,ToPort=80,IpRanges=[{CidrIp="$MY_IP"/32}]"
export HTTPS="IpProtocol=tcp,FromPort=443,ToPort=443,IpRanges=[{CidrIp="$MY_IP"/32}]"

aws ec2 authorize-security-group-ingress \
    --group-id $MY_SG \
    --group-name "cks-sg" \
    --ip-permissions $SYNTAX

aws ec2 authorize-security-group-ingress \
    --group-id $MY_SG \
    --group-name "cks-sg" \
    --ip-permissions $SSH

aws ec2 authorize-security-group-ingress \
    --group-id $MY_SG \
    --group-name "cks-sg" \
    --ip-permissions $HTTP

aws ec2 authorize-security-group-ingress \
    --group-id $MY_SG \
    --group-name "cks-sg" \
    --ip-permissions $HTTPS

