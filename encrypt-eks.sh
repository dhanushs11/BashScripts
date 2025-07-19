#!/bin/bash

KMS_ARN=""
EKS_CLUSTER_NAME=""
REGION_CODE=""

aws eks associate-encryption-config \
    --cluster-name $EKS_CLUSTER_NAME \
    --encryption-config '[{"resources":["secrets"],"provider":{"keyArn":"$KMS_ARN"}}]'