#!/bin/bash
# 무중단(Rolling) 배포: 인스턴스를 한 대씩 타겟 그룹에서 빼고 → 컨테이너 교체 → 다시 넣는다.
# 사용법: source infra/env.sh && bash infra/deploy.sh <새태그>   예) v1.0.1-26-11-16-2
set -e
export MSYS_NO_PATHCONV=1
. infra/.ids.$PFX
NEW_TAG=$1; [ -n "$NEW_TAG" ] || { echo "usage: deploy.sh <tag>"; exit 1; }
IMAGE=$ECR/$REPO:$NEW_TAG
# 새 이미지가 ECR 에 있는지 확인(없으면 여기서 중단)
aws ecr describe-images --repository-name $REPO --image-ids imageTag=$NEW_TAG >/dev/null
aws autoscaling suspend-processes --auto-scaling-group-name $PFX-asg --scaling-processes HealthCheck ReplaceUnhealthy
trap 'aws autoscaling resume-processes --auto-scaling-group-name $PFX-asg --scaling-processes HealthCheck ReplaceUnhealthy' EXIT
IDS=$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names $PFX-asg --query 'AutoScalingGroups[0].Instances[?LifecycleState==`InService`].InstanceId' --output text)
for I in $IDS; do
  echo "== $I : 타겟 그룹에서 제외 (draining)"
  aws elbv2 deregister-targets --target-group-arn $TG --targets Id=$I
  while [ "$(aws elbv2 describe-target-health --target-group-arn $TG --targets Id=$I --query 'TargetHealthDescriptions[0].TargetHealth.State' --output text)" != unused ]; do
    echo "   draining..."; sleep 5; done
  echo "== $I : 컨테이너 교체 ($NEW_TAG)"
  CID=$(aws ssm send-command --instance-ids $I --document-name AWS-RunShellScript --parameters "commands=[\"/opt/umc/swap.sh $IMAGE\"]" --query Command.CommandId --output text)
  aws ssm wait command-executed --command-id $CID --instance-id $I
  echo "== $I : 타겟 그룹에 다시 등록"
  aws elbv2 register-targets --target-group-arn $TG --targets Id=$I
  aws elbv2 wait target-in-service --target-group-arn $TG --targets Id=$I
  echo "   $I healthy"
done
# 이후 ASG 가 새로 띄우는 인스턴스도 새 버전을 쓰도록 기록
aws ssm put-parameter --name /$PFX/image --value "$IMAGE" --type String --overwrite >/dev/null
echo "배포 완료: $IMAGE"
