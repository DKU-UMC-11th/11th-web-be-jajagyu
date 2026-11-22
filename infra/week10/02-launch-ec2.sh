# RDS가 available 이 된 뒤 EC2를 띄운다. 사용: source infra/env.sh && bash infra/week10/02-launch-ec2.sh
set -e
export MSYS_NO_PATHCONV=1
. infra/week10/.ids

echo "RDS 준비를 기다리는 중..."
aws rds wait db-instance-available --db-instance-identifier umc10-db
H=$(aws rds describe-db-instances --db-instance-identifier umc10-db --query 'DBInstances[0].Endpoint.Address' --output text)
aws ssm put-parameter --name /umc10/db-host --value "$H" --type String --overwrite >/dev/null

AMI=$(aws ssm get-parameter --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 --query Parameter.Value --output text)
SUB=$(echo $SUBNETS | cut -d' ' -f1)
aws ec2 run-instances --image-id $AMI --instance-type t3.small --subnet-id $SUB --security-group-ids $APP_SG \
  --iam-instance-profile Name=umc10-ec2-profile --associate-public-ip-address \
  --user-data fileb://infra/week10/userdata.sh \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Project,Value=umc-w10},{Key=Name,Value=umc10-app}]" \
  --query 'Instances[0].InstanceId' --output text > infra/week10/.instance
I=$(cat infra/week10/.instance)
aws ec2 wait instance-running --instance-ids $I
aws ec2 describe-instances --instance-ids $I --query 'Reservations[0].Instances[0].PublicIpAddress' --output text > infra/week10/.ip
echo "EC2 실행됨: $(cat infra/week10/.ip) (앱이 뜨기까지 2~3분 더 걸린다)"
