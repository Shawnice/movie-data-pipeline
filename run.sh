#!/usr/bin/env bash

export $(xargs < env)
# Options: true/false
IsProduction='true'
FUNCTION_NAME='ReadIMDBFunction'

invoke_cmd="sam local invoke $FUNCTION_NAME -e events/event.json"
parameter_overrides="DBSecretName=DBSecretName IsProduction=$IsProduction \
BucketName=$BucketName LambdaSecurityGroup=$LambdaSecurityGroup LambdaSubnets=$LambdaSubnets \
DBHost=$DBHost DBUser=$DBUser DBPassword=$DBPassword SecretArn=$SecretArn \
RouteTableIds=$RouteTableIds VpcId=$VpcId S3VPCEndpointServiceName=$S3VPCEndpointServiceName \
SecretManagerVPCEndpointServiceName=$SecretManagerVPCEndpointServiceName"

if [ $1 = "invoke" ]; then
  eval "$invoke_cmd --parameter-overrides $parameter_overrides"
fi

if [ $1 = "build_and_invoke" ]; then
  sam build
  eval "$invoke_cmd --parameter-overrides $parameter_overrides"
fi

if [ $1 = "deploy" ]; then
  sam build
  sam deploy --parameter-overrides $parameter_overrides --no-confirm-changeset
fi
