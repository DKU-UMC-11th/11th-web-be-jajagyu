# 시작 템플릿 / 타겟 그룹 / ALB / ASG 생성 (source infra/env.sh 후 실행)
set -e
export MSYS_NO_PATHCONV=1
. infra/.ids
UD=$(base64 -w0 infra/userdata.sh)
cat > infra/.lt.json <<JSON
{"ImageId":"$AMI","InstanceType":"t3.small","SecurityGroupIds":["$APP_SG"],"IamInstanceProfile":{"Name":"umc-ec2-profile"},"UserData":"$UD",
 "TagSpecifications":[{"ResourceType":"instance","Tags":[{"Key":"Project","Value":"umc-w1"},{"Key":"Name","Value":"umc-app"}]}]}
JSON
aws ec2 create-launch-template --launch-template-name umc-app-lt --launch-template-data file://infra/.lt.json --tag-specifications "ResourceType=launch-template,Tags=[{Key=Project,Value=umc-w1}]" --query LaunchTemplate.LaunchTemplateId --output text
rm infra/.lt.json
TG=$(aws elbv2 create-target-group --name umc-app-tg --protocol HTTP --port 8080 --vpc-id $VPC --health-check-path /health --health-check-interval-seconds 10 --healthy-threshold-count 2 --unhealthy-threshold-count 2 --tags $TAGS --query 'TargetGroups[0].TargetGroupArn' --output text)
aws elbv2 modify-target-group-attributes --target-group-arn $TG --attributes Key=deregistration_delay.timeout_seconds,Value=30 >/dev/null
ALB=$(aws elbv2 create-load-balancer --name umc-alb --subnets $SUBNETS --security-groups $ALB_SG --tags $TAGS --query 'LoadBalancers[0].LoadBalancerArn' --output text)
aws elbv2 create-listener --load-balancer-arn $ALB --protocol HTTP --port 80 --default-actions Type=forward,TargetGroupArn=$TG >/dev/null
aws autoscaling create-auto-scaling-group --auto-scaling-group-name umc-asg --launch-template LaunchTemplateName=umc-app-lt,Version='$Latest' --min-size 2 --max-size 4 --desired-capacity 2 --vpc-zone-identifier "$(echo $SUBNETS | tr ' ' ',')" --target-group-arns $TG --health-check-type ELB --health-check-grace-period 120 --tags Key=Project,Value=umc-w1,PropagateAtLaunch=true
echo "TG=$TG ALB=$ALB" >> infra/.ids
aws elbv2 describe-load-balancers --load-balancer-arns $ALB --query 'LoadBalancers[0].DNSName' --output text | tee infra/.alb_dns
