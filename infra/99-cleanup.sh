# 전부 삭제 (비용 중지). source infra/env.sh 후 실행.
export MSYS_NO_PATHCONV=1; . infra/.ids.$PFX
aws autoscaling delete-auto-scaling-group --auto-scaling-group-name $PFX-asg --force-delete
aws elbv2 delete-load-balancer --load-balancer-arn $ALB
aws rds delete-db-instance --db-instance-identifier $PFX-db --skip-final-snapshot --delete-automated-backups >/dev/null
echo "ASG 인스턴스 종료/ALB 삭제 대기..."; sleep 120
aws elbv2 delete-target-group --target-group-arn $TG
aws ec2 delete-launch-template --launch-template-name $PFX-app-lt >/dev/null
aws rds wait db-instance-deleted --db-instance-identifier $PFX-db
for sg in $DB_SG $APP_SG $ALB_SG; do aws ec2 delete-security-group --group-id $sg; done
for n in image db-host db-user db-name db-password jwt-secret db-pool-size db-conn-timeout mysql-dsn; do aws ssm delete-parameter --name /$PFX/$n; done
aws iam remove-role-from-instance-profile --instance-profile-name $PFX-ec2-profile --role-name $PFX-ec2-role
aws iam delete-instance-profile --instance-profile-name $PFX-ec2-profile
for p in AmazonSSMManagedInstanceCore AmazonEC2ContainerRegistryReadOnly CloudWatchAgentServerPolicy; do aws iam detach-role-policy --role-name $PFX-ec2-role --policy-arn arn:aws:iam::aws:policy/$p; done
aws iam delete-role-policy --role-name $PFX-ec2-role --policy-name read-$PFX-params
aws iam delete-role --role-name $PFX-ec2-role
aws ecr delete-repository --repository-name $REPO --force >/dev/null
