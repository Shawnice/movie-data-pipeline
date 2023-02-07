#!/usr/bin/env bash

BucketName='<Bucket_Name_For_IMDB_Data>'
LambdaSecurityGroup='<Security_Group_For_Lambda>'
LambdaSubnets='<Subnets_for_Lambda>'
DBHost='<Database_Host>'
DBName='<Database_Name>'
# If IsProduction=true, username and password will retrieve from Secret Manager
DBUser='<Database_User>'
DBPassword='<Database_Password>'
DBSecretName='<Secret_Name_For_DB_Credential>'
SecretArn='<Secret_Manager_ARN>'
RouteTableIds='<Route_Table_Ids>'
VpcId='<VPC_ID>'
S3VPCEndpointServiceName='<S3_VPC_Endpoint_Service_Name>'
SecretManagerVPCEndpointServiceName='<SM_VPC_Endpoint_Service_Name>'
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
