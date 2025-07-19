#!/bin/bash

# Define variables
NAMESPACE="default"
AWS_REGION="ap-southeast-1" 
CLUSTER_NAME=""
ROLE_NAME=""
ROLE_DESCRIPTION="Role for MS pod to connect to KMS and S3"
BUCKETPOLICYNAME=""
BUCKET_NAME=""
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text)
TRUST_RELATIONSHIP_FILE=""
S3KMSKEYARN=""
KMSPOLICYNAME=""

cat >s3-access-policy.json <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:DeleteObject",
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::$BUCKET_NAME/*",
                "arn:aws:s3:::$BUCKET_NAME"
            ]
        }
    ]
}
EOF

cat >kms-policy.json <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "kms:GenerateDataKey",
                "kms:Decrypt"
            ],
            "Resource": "$S3KMSKEYARN"
        }
    ]
}
EOF


aws iam create-policy --policy-name "$BUCKETPOLICYNAME" --policy-document file://s3-access-policy.json
aws iam create-policy --policy-name "$KMSPOLICYNAME" --policy-document file://kms-policy.json
# Create a ServiceAccount
echo "Creating a ServiceAccount..."
cat > service-account.yaml <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: serviceaccount
  namespace: "$NAMESPACE"
EOF

kubectl apply -f service-account.yaml

# Get OIDC Provider URL
echo "Getting OIDC Provider URL..."
OIDC_PROVIDER=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" --query "cluster.identity.oidc.issuer" --output text | sed -e "s/^https:\/\///")

# Create Trust Relationship Policy Document
echo "Creating Trust Relationship Policy Document..."
cat > "$TRUST_RELATIONSHIP_FILE" <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::$AWS_ACCOUNT_ID:oidc-provider/$OIDC_PROVIDER"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "$OIDC_PROVIDER:aud": "sts.amazonaws.com",
                    "$OIDC_PROVIDER:sub": "system:serviceaccount:$NAMESPACE:serviceaccount"
                }
            }
        }
    ]
}
EOF

# Create IAM Role
echo "Creating IAM Role..."
aws iam create-role --role-name "$ROLE_NAME" --assume-role-policy-document file://"$TRUST_RELATIONSHIP_FILE" --description "$ROLE_DESCRIPTION"

# Attach IAM Policies
echo "Attaching IAM Policies..."
aws iam attach-role-policy --role-name "$ROLE_NAME" --policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/$BUCKETPOLICYNAME
aws iam attach-role-policy --role-name "$ROLE_NAME" --policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/$KMSPOLICYNAME
# Annotate the ServiceAccount with the IAM Role ARN
echo "Annotating the ServiceAccount with the IAM Role ARN..."
kubectl annotate serviceaccount -n "$NAMESPACE" "serviceaccount" eks.amazonaws.com/role-arn="arn:aws:iam::$AWS_ACCOUNT_ID:role/$ROLE_NAME"

# Get AssumeRolePolicyDocument for IAM Role
echo "Getting AssumeRolePolicyDocument for IAM Role..."
aws iam get-role --role-name "$ROLE_NAME" --query Role.AssumeRolePolicyDocument

# Describe the ServiceAccount
echo "Describing the ServiceAccount..."
kubectl describe serviceaccount "" -n "$NAMESPACE"