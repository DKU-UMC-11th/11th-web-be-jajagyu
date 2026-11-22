# 전부 삭제 (비용 중지). source infra/env.sh 후 실행.
export MSYS_NO_PATHCONV=1; . infra/.ids
aws autoscaling delete-auto-scaling-group --auto-scaling-group-name umc-asg --force-delete
aws elbv2 delete-load-balancer --load-balancer-arn $ALB
aws rds delete-db-instance --db-instance-identifier umc-db --skip-final-snapshot --delete-automated-backups >/dev/null
echo "ASG 인스턴스 종료/ALB 삭제 대기..."; sleep 120
aws elbv2 delete-target-group --target-group-arn $TG
aws ec2 delete-launch-template --launch-template-name umc-app-lt >/dev/null
aws rds wait db-instance-deleted --db-instance-identifier umc-db
for sg in $DB_SG $APP_SG $ALB_SG; do aws ec2 delete-security-group --group-id $sg; done
for n in image db-host db-user db-name db-password jwt-secret; do aws ssm delete-parameter --name /umc/$n; done
aws iam remove-role-from-instance-profile --instance-profile-name umc-ec2-profile --role-name umc-ec2-role
aws iam delete-instance-profile --instance-profile-name umc-ec2-profile
for p in AmazonSSMManagedInstanceCore AmazonEC2ContainerRegistryReadOnly; do aws iam detach-role-policy --role-name umc-ec2-role --policy-arn arn:aws:iam::aws:policy/$p; done
aws iam delete-role-policy --role-name umc-ec2-role --policy-name read-umc-params
aws iam delete-role --role-name umc-ec2-role
aws ecr delete-repository --repository-name $REPO --force >/dev/null
