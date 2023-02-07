# IMDB movie data ETL pipeline

A micro pipeline for loading IMDB dataset into a database. When a
semi-structured IMDB dataset is loaded into S3 bucket, it will trigger a AWS
Lambda function to process the dataset and store it to a AWS RDS(MySQL).

## Prerequisites

1. Install AWS CLI
2. Install AWS SAM CLI
3. Install Docker

## How to run

When make any change run `sam build` before invoke the Lambda function. It will
process the template file and ensure the application code, dependencies are
copied to the right location to be run.

Run the following command to invoke the Lambda function locally.

```shell
sam local invoke "ReadIMDBFunction" -e events/event.json \
--parameter-overrides DBHost=<DBHost> DBName=<DBName> DBUser=<DBUser> DBPassword=<DBPassword>
``` 

See an example:

```shell
sam local invoke "ReadIMDBFunction" -e events/event.json \
--parameter-overrides DBHost='docker.for.mac.localhost' DBName='mysql' DBUser='root' DBPassword='12345678'
```


### Useful tool

`run.sh` provides options for invoking, building, and deploying resources.

- To invoke the Lambda function, run:

`./run.sh invoke`

- To build and invoke the Lambda function, run:

`./run.sh build_and_invoke`

- To build and deploy the Lambda function and related resources, run:

`./run.sh deploy`

Before running the script, please ensure replace values for the below arguments
in the script, it will automatically override parameters defined in the
`template.yaml`.

```shell
BucketName='<Bucket_Name_For_IMDB_Data>'
LambdaSecurityGroup='<Security_Group_For_Lambda>'
LambdaSubnets='<Subnets_for_Lambda>'
DBHost='<Database_Host>'
DBName='<Database_Name>'
DBUser='<Database_User>'
DBPassword='<Database_Password>'
DBSecretName='<Secret_Name_For_DB_Credential>'
SecretArn='<Secret_Manager_ARN>'
RouteTableIds='<Route_Table_Ids>'
VpcId='<VPC_ID>'
S3VPCEndpointServiceName='<S3_VPC_Endpoint_Service_Name>'
SecretManagerVPCEndpointServiceName='<SM_VPC_Endpoint_Service_Name>'
IsProduction='true'
FUNCTION_NAME='ReadIMDBFunction'
```
