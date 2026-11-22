# 보안그룹 / SSM 파라미터 / IAM / RDS 생성 (source infra/env.sh 후 실행, 재실행 가능)
set -e
export MSYS_NO_PATHCONV=1  # Git Bash가 /umc/... 를 윈도우 경로로 바꾸지 않게
MYIP=$(curl -s https://checkip.amazonaws.com)
sg(){ id=$(aws ec2 describe-security-groups --filters Name=group-name,Values=$1 Name=vpc-id,Values=$VPC --query 'SecurityGroups[0].GroupId' --output text)
  if [ "$id" = None ]; then id=$(aws ec2 create-security-group --group-name $1 --description "$2" --vpc-id $VPC --tag-specifications "ResourceType=security-group,Tags=[{Key=Project,Value=umc-w1},{Key=Name,Value=$1}]" --query GroupId --output text); fi; echo $id; }
ALB_SG=$(sg umc-alb-sg "UMC ALB"); APP_SG=$(sg umc-app-sg "UMC app"); DB_SG=$(sg umc-db-sg "UMC db")
ing(){ aws ec2 authorize-security-group-ingress --group-id $1 --protocol tcp --port $2 "${@:3}" >/dev/null 2>&1 || true; }
ing $ALB_SG 80 --cidr 0.0.0.0/0
ing $APP_SG 8080 --source-group $ALB_SG
ing $APP_SG 8080 --cidr $MYIP/32   # 단일 배포 측정용(내 IP만)
ing $DB_SG 3306 --source-group $APP_SG
# 비밀값은 만들어서 SSM에만 저장(화면/파일에 출력하지 않음)
DBPW=$(openssl rand -hex 12); JWT=$(openssl rand -hex 32)
put(){ aws ssm put-parameter --name /umc/$1 --value "$2" --type ${3:-String} --overwrite >/dev/null; }
put image "$ECR/$REPO:$TAG"; put db-user umc; put db-name movie; put db-password "$DBPW" SecureString; put jwt-secret "$JWT" SecureString
# IAM
aws iam create-role --role-name umc-ec2-role --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ec2.amazonaws.com"},"Action":"sts:AssumeRole"}]}' --tags $TAGS >/dev/null 2>&1 || true
for p in AmazonSSMManagedInstanceCore AmazonEC2ContainerRegistryReadOnly; do aws iam attach-role-policy --role-name umc-ec2-role --policy-arn arn:aws:iam::aws:policy/$p; done
aws iam put-role-policy --role-name umc-ec2-role --policy-name read-umc-params --policy-document "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Action\":[\"ssm:GetParameter\",\"ssm:GetParameters\",\"ssm:GetParametersByPath\"],\"Resource\":\"arn:aws:ssm:$AWS_REGION:$ACCT:parameter/umc/*\"}]}"
aws iam create-instance-profile --instance-profile-name umc-ec2-profile --tags $TAGS >/dev/null 2>&1 || true
aws iam add-role-to-instance-profile --instance-profile-name umc-ec2-profile --role-name umc-ec2-role 2>/dev/null || true
# RDS
aws rds create-db-instance --db-instance-identifier umc-db --engine mysql --engine-version 8.0 --db-instance-class db.t3.micro --allocated-storage 20 --db-name movie --master-username umc --master-user-password "$DBPW" --vpc-security-group-ids $DB_SG --no-publicly-accessible --backup-retention-period 0 --tags $TAGS --query 'DBInstance.DBInstanceStatus' --output text
echo "ALB_SG=$ALB_SG APP_SG=$APP_SG DB_SG=$DB_SG" > infra/.ids   # 내부 ID만 (비밀 아님)
