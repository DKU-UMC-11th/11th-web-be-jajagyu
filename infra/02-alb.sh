# 시작 템플릿 / 타겟 그룹 / ALB / ASG 생성 (source infra/env.sh 후 실행)
set -e
export MSYS_NO_PATHCONV=1
. infra/.ids.$PFX
UD=$(sed -e "s#--name /umc/#--name /$PFX/#g" -e "s#--name \"/umc/#--name \"/$PFX/#g" -e "s#__PFX__#$PFX#g" infra/userdata.sh | base64 -w0)
cat > infra/.lt.json <<JSON
{"ImageId":"$AMI","InstanceType":"t3.small","SecurityGroupIds":["$APP_SG"],"IamInstanceProfile":{"Name":"$PFX-ec2-profile"},"UserData":"$UD",
 "TagSpecifications":[{"ResourceType":"instance","Tags":[{"Key":"Project","Value":"$PFX-w1"},{"Key":"Name","Value":"$PFX-app"}]}]}
JSON
aws ec2 create-launch-template --launch-template-name $PFX-app-lt --launch-template-data file://infra/.lt.json --tag-specifications "ResourceType=launch-template,Tags=[{Key=Project,Value=$PFX-w1}]" --query LaunchTemplate.LaunchTemplateId --output text
rm infra/.lt.json
TG=$(aws elbv2 create-target-group --name $PFX-app-tg --protocol HTTP --port 8080 --vpc-id $VPC --health-check-path /health --health-check-interval-seconds 10 --healthy-threshold-count 2 --unhealthy-threshold-count 2 --tags $TAGS --query 'TargetGroups[0].TargetGroupArn' --output text)
aws elbv2 modify-target-group-attributes --target-group-arn $TG --attributes Key=deregistration_delay.timeout_seconds,Value=30 >/dev/null
ALB=$(aws elbv2 create-load-balancer --name $PFX-alb --subnets $SUBNETS --security-groups $ALB_SG --tags $TAGS --query 'LoadBalancers[0].LoadBalancerArn' --output text)
aws elbv2 create-listener --load-balancer-arn $ALB --protocol HTTP --port 80 --default-actions Type=forward,TargetGroupArn=$TG >/dev/null
aws autoscaling create-auto-scaling-group --auto-scaling-group-name $PFX-asg --launch-template LaunchTemplateName=$PFX-app-lt,Version='$Latest' --min-size ${ASG_MIN:-2} --max-size 4 --desired-capacity ${ASG_DESIRED:-2} --vpc-zone-identifier "$(echo $SUBNETS | tr ' ' ',')" --target-group-arns $TG --health-check-type ELB --health-check-grace-period 120 --tags Key=Project,Value=$PFX-w1,PropagateAtLaunch=true
echo "TG=$TG ALB=$ALB" >> infra/.ids.$PFX
aws elbv2 describe-load-balancers --load-balancer-arns $ALB --query 'LoadBalancers[0].DNSName' --output text | tee infra/.alb_dns.$PFX
