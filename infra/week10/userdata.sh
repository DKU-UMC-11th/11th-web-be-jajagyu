#!/bin/bash
# EC2 첫 부팅 때 한 번 실행된다: JDK 설치 → JAR 내려받기 → (처음이면) 스키마 적용 → 서비스로 실행.
# 비밀 값(DB 비밀번호, JWT 키)은 이 파일이 아니라 SSM Parameter Store(SecureString)에서 읽는다.
exec > /var/log/movie-bootstrap.log 2>&1
set -x
dnf install -y java-21-amazon-corretto-headless mariadb105 iptables-nft

TOKEN=$(curl -s -X PUT http://169.254.169.254/latest/api/token -H 'X-aws-ec2-metadata-token-ttl-seconds: 60')
export AWS_DEFAULT_REGION=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/region)
p() { aws ssm get-parameter --name "/umc10/$1" --with-decryption --query Parameter.Value --output text; }
BUCKET=$(p artifact-bucket)

mkdir -p /opt/movie
aws s3 cp "s3://$BUCKET/movie-app.jar" /opt/movie/movie-app.jar
aws s3 cp "s3://$BUCKET/01_schema.sql" /opt/movie/01_schema.sql

# 실행 환경 파일: root만 읽을 수 있게 한다.
umask 077
cat > /etc/movie-app.env <<ENV
SPRING_PROFILES_ACTIVE=prod
DB_HOST=$(p db-host)
DB_NAME=umc_movie
DB_USER=$(p db-user)
DB_PASSWORD=$(p db-password)
JWT_SECRET=$(p jwt-secret)
FRONTEND_ORIGIN=$(p frontend-origin)
ENV
umask 022

# 운영 스키마는 앱이 자동으로 만들지 않는다(ddl-auto: validate). 테이블이 없을 때만 준비된 스키마 파일을 적용한다.
set -a; . /etc/movie-app.env; set +a
if ! MYSQL_PWD="$DB_PASSWORD" mysql -h "$DB_HOST" -u "$DB_USER" -N -e "SELECT 1 FROM umc_movie.member LIMIT 1" >/dev/null 2>&1; then
  MYSQL_PWD="$DB_PASSWORD" mysql -h "$DB_HOST" -u "$DB_USER" < /opt/movie/01_schema.sql
fi

# SSH 연결이 없어도(닫아도) 살아 있고, 재부팅 뒤에도 다시 시작되게 systemd 서비스로 등록한다.
cat > /etc/systemd/system/movie-app.service <<UNIT
[Unit]
Description=Movie rating service
After=network-online.target

[Service]
EnvironmentFile=/etc/movie-app.env
ExecStart=/usr/bin/java -jar /opt/movie/movie-app.jar
Restart=on-failure
User=root

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable --now movie-app

# 80 포트로 들어오는 요청도 앱(8080)으로 보낸다. (80/8080 어느 쪽으로 접속해도 된다)
iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-ports 8080
