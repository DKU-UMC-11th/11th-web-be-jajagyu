# 10주차: RDS(MySQL) + EC2 + S3(JAR 전달용) 생성. 사용: source infra/env.sh && bash infra/week10/01-create.sh
# 모든 리소스에 Project=umc-w10 태그를 달아 정리할 때 한 번에 찾는다.
set -e
export MSYS_NO_PATHCONV=1
T="Key=Project,Value=umc-w10"
MYIP=$(curl -s https://checkip.amazonaws.com)

sg() { id=$(aws ec2 describe-security-groups --filters Name=group-name,Values=$1 Name=vpc-id,Values=$VPC --query 'SecurityGroups[0].GroupId' --output text)
  if [ "$id" = None ]; then id=$(aws ec2 create-security-group --group-name $1 --description "$2" --vpc-id $VPC --tag-specifications "ResourceType=security-group,Tags=[{Key=Project,Value=umc-w10},{Key=Name,Value=$1}]" --query GroupId --output text); fi; echo $id; }
ing() { aws ec2 authorize-security-group-ingress --group-id $1 --protocol tcp --port $2 "${@:3}" >/dev/null 2>&1 || true; }

APP_SG=$(sg umc10-app-sg "umc10 app"); DB_SG=$(sg umc10-db-sg "umc10 db")
ing $APP_SG 8080 --cidr 0.0.0.0/0     # 프론트 사용자가 접근하는 앱 포트
ing $APP_SG 80 --cidr 0.0.0.0/0       # 80 -> 8080 (프록시 서비스 호환용)
ing $DB_SG 3306 --source-group $APP_SG # DB는 EC2 보안 그룹에서 오는 연결만 허용 (0.0.0.0/0 아님)
# SSH(22)는 열지 않는다. 서버 접속은 SSM Session/Run Command 로 한다.

# 비밀 값은 만들어서 SSM(SecureString)에만 저장한다. (화면/파일에 출력하지 않는다)
DBPW=$(openssl rand -hex 14); JWT=$(openssl rand -hex 32)
put() { aws ssm put-parameter --name /umc10/$1 --value "$2" --type ${3:-String} --overwrite >/dev/null; }
put db-user umc; put db-password "$DBPW" SecureString; put jwt-secret "$JWT" SecureString
put frontend-origin "${FRONTEND_ORIGIN:-https://umcine.vercel.app}"

# 결과물(JAR, 스키마) 전달용 비공개 버킷
BUCKET=umc10-artifacts-$ACCT
aws s3api create-bucket --bucket $BUCKET --region $AWS_REGION --create-bucket-configuration LocationConstraint=$AWS_REGION >/dev/null 2>&1 || true
aws s3api put-public-access-block --bucket $BUCKET --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
aws s3api put-bucket-tagging --bucket $BUCKET --tagging 'TagSet=[{Key=Project,Value=umc-w10}]'
put artifact-bucket $BUCKET
aws s3 cp build/libs/movie-0.0.1-SNAPSHOT.jar s3://$BUCKET/movie-app.jar --only-show-errors
aws s3 cp sql/01_schema.sql s3://$BUCKET/01_schema.sql --only-show-errors

# IAM: EC2가 SSM 접속, 비밀 값 읽기, 버킷 읽기만 하도록 최소 권한
aws iam create-role --role-name umc10-ec2-role --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ec2.amazonaws.com"},"Action":"sts:AssumeRole"}]}' --tags $T >/dev/null 2>&1 || true
aws iam attach-role-policy --role-name umc10-ec2-role --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
aws iam put-role-policy --role-name umc10-ec2-role --policy-name umc10-read --policy-document "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Action\":[\"ssm:GetParameter\"],\"Resource\":\"arn:aws:ssm:$AWS_REGION:$ACCT:parameter/umc10/*\"},{\"Effect\":\"Allow\",\"Action\":[\"s3:GetObject\"],\"Resource\":\"arn:aws:s3:::$BUCKET/*\"}]}"
aws iam create-instance-profile --instance-profile-name umc10-ec2-profile --tags $T >/dev/null 2>&1 || true
aws iam add-role-to-instance-profile --instance-profile-name umc10-ec2-profile --role-name umc10-ec2-role 2>/dev/null || true

# RDS: 퍼블릭 액세스 끔, DB 보안 그룹만 허용
aws rds create-db-instance --db-instance-identifier umc10-db --engine mysql --engine-version 8.0 --db-instance-class db.t3.micro --allocated-storage 20 --db-name umc_movie --master-username umc --master-user-password "$DBPW" --vpc-security-group-ids $DB_SG --no-publicly-accessible --backup-retention-period 0 --tags $T --query 'DBInstance.DBInstanceStatus' --output text
echo "APP_SG=$APP_SG DB_SG=$DB_SG BUCKET=$BUCKET" > infra/week10/.ids   # 내부 ID만 (비밀 아님)
echo "RDS 생성 시작. 완료까지 5~10분 걸린다."
