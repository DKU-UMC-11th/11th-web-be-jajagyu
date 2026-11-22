#!/bin/bash
dnf install -y docker
systemctl enable --now docker
mkdir -p /opt/umc
cat > /opt/umc/swap.sh <<'SWAP'
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
docker run -d --name app --restart always -p 8080:8080 \
  -e DB_URL="jdbc:mysql://$(p db-host):3306/$(p db-name)" -e DB_USER=$(p db-user) -e DB_PW=$(p db-password) \
  -e JWT_SECRET=$(p jwt-secret) -e JWT_ACCESS_EXPIRATION=3600 $IMAGE
for i in $(seq 1 60); do curl -sf localhost:8080/health >/dev/null && echo healthy && exit 0; sleep 2; done
echo "health check failed"; exit 1
SWAP
chmod +x /opt/umc/swap.sh
/opt/umc/swap.sh >> /var/log/umc-swap.log 2>&1
# 관측 수집기 — 2주차 3.3 (Alloy). SSM 값은 /umc/gc-* 로 둔다(이 스택의 /umc/<이름> 규칙).
# 토큰이 아직 없어도 앱 배포는 막지 않는다(|| true). 설정은 Fleet Management 가 5분마다 내려준다.
mkdir -p /opt/alloy /var/lib/alloy
q(){ aws ssm get-parameter --region ap-northeast-2 --name "/umc/$1" --with-decryption --query Parameter.Value --output text 2>/dev/null || true; }
export GC_FLEET_URL=$(q gc-fleet-url) GC_FLEET_USER=$(q gc-fleet-user) GC_TOKEN=$(q gc-token)
export GCLOUD_RW_API_KEY="$GC_TOKEN" GC_PROM_URL=$(q gc-prom-url) GC_PROM_USER=$(q gc-prom-user) MYSQL_DSN=$(q mysql-dsn)
export APP_METRICS_ADDR=127.0.0.1:8080 APP_METRICS_PATH=/actuator/prometheus   # Spring Boot 용 (03 파이프라인이 읽는다)
cat > /opt/alloy/config.alloy <<'ALLOY'
logging { level = "info" }
remotecfg {
  url = sys.env("GC_FLEET_URL")
  basic_auth {
    username = sys.env("GC_FLEET_USER")
    password = sys.env("GC_TOKEN")
  }
  id             = constants.hostname
  poll_frequency = "5m"
}
ALLOY
docker run -d --name alloy --restart unless-stopped --network host --pid host \
  -v /:/rootfs:ro -v /var/run/docker.sock:/var/run/docker.sock:ro \
  -v /opt/alloy/config.alloy:/etc/alloy/config.alloy:ro -v /var/lib/alloy:/var/lib/alloy \
  -e GC_FLEET_URL -e GC_FLEET_USER -e GC_TOKEN -e GC_PROM_URL -e GC_PROM_USER -e MYSQL_DSN \
  -e GCLOUD_RW_API_KEY -e APP_METRICS_ADDR -e APP_METRICS_PATH \
  grafana/alloy:v1.20.1 run --storage.path=/var/lib/alloy /etc/alloy/config.alloy >> /var/log/umc-alloy.log 2>&1 || true
