export AWS_REGION=ap-northeast-2 AWS_DEFAULT_REGION=ap-northeast-2 AWS_PAGER=""
# 스택 이름 접두사. 같은 계정을 여러 명이 쓰면 이름이 겹쳐 서로 덮어쓰므로 접두사로 분리한다. (기존 스택은 PFX=umc)
export PFX=${PFX:-umc3}
export ACCT=$(aws sts get-caller-identity --query Account --output text)
export ECR=$ACCT.dkr.ecr.$AWS_REGION.amazonaws.com
export REPO=$PFX-movie
export TAG=${TAG:-v1.0.0-26-11-16-1}   # 버전-yy-mm-dd-N
export VPC=$(aws ec2 describe-vpcs --filters Name=isDefault,Values=true --query 'Vpcs[0].VpcId' --output text)
export SUBNETS=$(aws ec2 describe-subnets --filters Name=vpc-id,Values=$VPC Name=default-for-az,Values=true --query 'Subnets[].SubnetId' --output text | tr '\t' ' ')
export TAGS="Key=Project,Value=$PFX-w1"
