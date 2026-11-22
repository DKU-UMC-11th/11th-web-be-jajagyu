#!/bin/bash
# 인스턴스 안에서 실행: SSM 에서 설정을 읽어 컨테이너를 교체한다.
set -e
export AWS_DEFAULT_REGION=$(curl -s -H "X-aws-ec2-metadata-token: $(curl -s -X PUT http://169.254.169.254/latest/api/token -H 'X-aws-ec2-metadata-token-ttl-seconds: 60')" http://169.254.169.254/latest/meta-data/placement/region)
p(){ aws ssm get-parameter --name /umc/$1 --with-decryption --query Parameter.Value --output text; }
IMAGE=${1:-$(p image)}
aws ecr get-login-password | docker login --username AWS --password-stdin ${IMAGE%%/*} >/dev/null
docker pull $IMAGE
docker stop -t 30 app 2>/dev/null || true   # graceful shutdown: 처리 중인 요청을 끝내고 종료
docker rm app 2>/dev/null || true
# 3주차: 풀 크기/연결 대기 시간은 선택 값. SSM 에 없으면 앱 기본값(10 / 30000ms)을 쓴다.
o(){ aws ssm get-parameter --name /umc/$1 --query Parameter.Value --output text 2>/dev/null || true; }
POOL=$(o db-pool-size); CTO=$(o db-conn-timeout)
docker run -d --name app --restart always -p 8080:8080 \
  -e DB_URL="jdbc:mysql://$(p db-host):3306/$(p db-name)" -e DB_USER=$(p db-user) -e DB_PW=$(p db-password) \
  -e JWT_SECRET=$(p jwt-secret) -e JWT_ACCESS_EXPIRATION=3600 ${POOL:+-e DB_POOL_SIZE=$POOL} ${CTO:+-e DB_CONN_TIMEOUT=$CTO} $IMAGE
for i in $(seq 1 60); do curl -sf localhost:8080/health >/dev/null && echo healthy && exit 0; sleep 2; done
echo "health check failed"; exit 1
