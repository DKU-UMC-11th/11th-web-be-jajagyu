#!/bin/bash
# 오토스케일링 관찰 기록: 30초마다 ASG 대수/타겟 헬스/알람 상태/평균 CPU·메모리를 한 줄씩 남긴다.
# 사용: source infra/env.sh && bash infra/asg-watch.sh <출력파일> [초]
export MSYS_NO_PATHCONV=1
OUT=$1; SEC=${2:-900}; . infra/.ids.$PFX
echo "time(UTC) desired inservice target_healthy high_alarms(cpu/mem) asg_cpu_avg% asg_mem_avg%" > $OUT
for i in $(seq 1 $((SEC/30))); do
  G=$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names $PFX-asg --query 'AutoScalingGroups[0].[DesiredCapacity,length(Instances[?LifecycleState==`InService`])]' --output text)
  H=$(aws elbv2 describe-target-health --target-group-arn $TG --query 'length(TargetHealthDescriptions[?TargetHealth.State==`healthy`])' --output text)
  A=$(aws cloudwatch describe-alarms --alarm-name-prefix TargetTracking-$PFX-asg-AlarmHigh --query 'MetricAlarms[].StateValue' --output text | tr '\t' '/')
  S=$(date -u -d '-3 minutes' +%FT%TZ); E=$(date -u +%FT%TZ)
  C=$(aws cloudwatch get-metric-statistics --namespace AWS/EC2 --metric-name CPUUtilization --dimensions Name=AutoScalingGroupName,Value=$PFX-asg --start-time $S --end-time $E --period 60 --statistics Average --query 'sort_by(Datapoints,&Timestamp)[-1].Average' --output text | cut -c1-5)
  M=$(aws cloudwatch get-metric-statistics --namespace CWAgent --metric-name mem_used_percent --dimensions Name=AutoScalingGroupName,Value=$PFX-asg --start-time $S --end-time $E --period 60 --statistics Average --query 'sort_by(Datapoints,&Timestamp)[-1].Average' --output text | cut -c1-5)
  echo "$(date -u +%H:%M:%S) $G $H $A $C $M" | tr '\t' ' ' >> $OUT
  sleep 30
done
