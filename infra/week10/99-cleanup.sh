# 10주차 리소스 전부 삭제(비용 중지). 사용: source infra/env.sh && bash infra/week10/99-cleanup.sh
export MSYS_NO_PATHCONV=1
. infra/week10/.ids
I=$(cat infra/week10/.instance 2>/dev/null)
[ -n "$I" ] && aws ec2 terminate-instances --instance-ids $I >/dev/null && aws ec2 wait instance-terminated --instance-ids $I
aws rds delete-db-instance --db-instance-identifier umc10-db --skip-final-snapshot --delete-automated-backups >/dev/null
aws rds wait db-instance-deleted --db-instance-identifier umc10-db
for sg in $DB_SG $APP_SG; do aws ec2 delete-security-group --group-id $sg; done
aws s3 rm s3://$BUCKET --recursive --only-show-errors && aws s3api delete-bucket --bucket $BUCKET
for n in db-user db-password jwt-secret frontend-origin artifact-bucket db-host; do aws ssm delete-parameter --name /umc10/$n 2>/dev/null; done
aws iam remove-role-from-instance-profile --instance-profile-name umc10-ec2-profile --role-name umc10-ec2-role
aws iam delete-instance-profile --instance-profile-name umc10-ec2-profile
aws iam detach-role-policy --role-name umc10-ec2-role --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
aws iam delete-role-policy --role-name umc10-ec2-role --policy-name umc10-read
aws iam delete-role --role-name umc10-ec2-role
echo "정리 완료"
