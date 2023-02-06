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
# Options: true/false
IsProduction='true'
FUNCTION_NAME='ReadIMDBFunction'

invoke_cmd="sam local invoke $FUNCTION_NAME -e events/event.json"
parameter_overrides="DBSecretName=DBSecretName IsProduction=$IsProduction \
BucketName=$BucketName LambdaSecurityGroup=$LambdaSecurityGroup LambdaSubnets=$LambdaSubnets \
DBHost=$DBHost DBUser=$DBUser DBPassword=$DBPassword"

if [ $1 = "invoke" ]; then
  eval "$invoke_cmd --parameter-overrides $parameter_overrides"
fi

if [ $1 = "build_and_invoke" ]; then
  sam build
  eval "$invoke_cmd --parameter-overrides $parameter_overrides"
fi

if [ $1 = "deploy" ]; then
  sam build
  sam deploy --parameter-overrides $parameter_overrides -no-confirm-changeset
fi
