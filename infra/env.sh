export AWS_REGION=ap-northeast-2 AWS_DEFAULT_REGION=ap-northeast-2 AWS_PAGER=""
export ACCT=$(aws sts get-caller-identity --query Account --output text)
export ECR=$ACCT.dkr.ecr.$AWS_REGION.amazonaws.com
export REPO=umc-movie
export TAG=${TAG:-v1.0.0-26-11-16-1}   # 버전-yy-mm-dd-N
export VPC=$(aws ec2 describe-vpcs --filters Name=isDefault,Values=true --query 'Vpcs[0].VpcId' --output text)
export SUBNETS=$(aws ec2 describe-subnets --filters Name=vpc-id,Values=$VPC Name=default-for-az,Values=true --query 'Subnets[].SubnetId' --output text | tr '\t' ' ')
export TAGS="Key=Project,Value=umc-w1"
