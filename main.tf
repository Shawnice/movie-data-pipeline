provider "aws" {
  region = var.region
}

# Local vars
locals {
  source_dir = "./src"
  requirements_path = "./src/requirements.txt"
  build_path = "./build"
  dependencies_path = "./build/dependencies"
  shared_requirements_path = "./build/shared/requirements.txt"
}

# IAM
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "iam_for_lambda" {
  name               = "iam_for_lambda"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

data "aws_iam_policy_document" "lambda_vpc_policy" {
  statement {
    effect    = "Allow"
    actions   = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "ec2:CreateNetworkInterface",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DeleteNetworkInterface",
        "ec2:AssignPrivateIpAddresses",
        "ec2:UnassignPrivateIpAddresses"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "lambda_vpc_policy" {
  name   = "lambda-vpc-policy"
  policy = data.aws_iam_policy_document.lambda_vpc_policy.json
}

resource "aws_iam_role_policy_attachment" "lambda_vpc_policy_attach" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.lambda_vpc_policy.arn
}

data "aws_iam_policy_document" "s3_policy" {
  statement {
    effect    = "Allow"
    actions   = ["s3:*"]
    resources = ["arn:aws:s3:::${aws_s3_bucket.s3_bucket.bucket}/*"]
  }
}

resource "aws_iam_policy" "s3_policy" {
  name   = "s3-policy"
  policy = data.aws_iam_policy_document.s3_policy.json
}

resource "aws_iam_role_policy_attachment" "s3_policy_attach" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.s3_policy.arn
}


data "aws_iam_policy_document" "sm_policy" {
  statement {
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [aws_db_instance.mysql_db.master_user_secret[0].secret_arn]
  }
}

resource "aws_iam_policy" "sm_policy" {
  name   = "sm-policy"
  policy = data.aws_iam_policy_document.sm_policy.json
}

resource "aws_iam_role_policy_attachment" "sm_policy_attach" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.sm_policy.arn
}

resource "aws_lambda_permission" "allow_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_imdb.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.s3_bucket.arn
}


# Lambda
resource "null_resource" "sam_metadata_pip_install" {
  triggers = {
    resource_name = "aws_lambda_function.lambda_imdb"
    resource_type = "ZIP_LAMBDA_FUNCTION"
    original_source_code = local.source_dir
    built_output_path = local.dependencies_path
    dependencies = filemd5(local.requirements_path)
    source_code_hash = filemd5("${local.source_dir}/app.py")
  }

  provisioner "local-exec" {
    command = <<EOT
      rm -rf ${local.dependencies_path}
      pip install -r ${local.requirements_path} -t ${local.dependencies_path} \
      --platform manylinux2014_x86_64 --only-binary=:all: --implementation cp --upgrade
      cp ${local.source_dir}/app.py ${local.dependencies_path}
    EOT
  }
}

data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = local.dependencies_path
  output_path = "${local.build_path}/lambda_payload.zip"
  depends_on = [null_resource.sam_metadata_pip_install]
}

resource "aws_lambda_function" "lambda_imdb" {
  filename      = "${local.build_path}/lambda_payload.zip"
  function_name = "ReadIMDBFunction"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "app.lambda_imdb"
  architectures = ["x86_64"]

  depends_on = [null_resource.sam_metadata_pip_install]
  layers = [aws_lambda_layer_version.shared_python_libs.arn]

  source_code_hash = data.archive_file.lambda.output_base64sha256
  timeout          = 15
  runtime          = "python3.9"

  vpc_config {
    subnet_ids         = [aws_default_subnet.default_az1.id]
    security_group_ids = [aws_security_group.lambda-sg.id]
  }

  environment {
    variables = {
      DBHost       = var.is_production ? aws_db_instance.mysql_db.address : var.db_host
      DBName       = var.is_production ? aws_db_instance.mysql_db.db_name : var.db_name
      DBUser       = var.db_user
      DBPassword   = var.db_password
      SecretArn    = var.is_production ? aws_db_instance.mysql_db.master_user_secret[0].secret_arn : ""
      IsProduction = var.is_production
    }
  }
}

resource "null_resource" "shared_python_libs" {
  triggers = {
    dependencies = filemd5(local.shared_requirements_path)
  }

  provisioner "local-exec" {
    command = <<EOT
      pip install -r ${local.shared_requirements_path} -t ${local.build_path}/shared/python \
      --platform manylinux2014_x86_64 --only-binary=:all: --implementation cp --upgrade
    EOT
  }
}

data "archive_file" "shared_python_libs" {
  type        = "zip"
  source_dir  = "${local.build_path}/shared/"
  output_path = "${local.build_path}/lambda_layer_payload.zip"
  depends_on = [null_resource.shared_python_libs]
}

resource "aws_lambda_layer_version" "shared_python_libs" {
  filename   = "${local.build_path}/lambda_layer_payload.zip"
  layer_name = "shared_python_libs"

  source_code_hash = data.archive_file.shared_python_libs.output_base64sha256

  compatible_runtimes = ["python3.9"]
}


# S3
resource "aws_s3_bucket" "s3_bucket" {
  bucket = "movie-data-terraform"
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.s3_bucket.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.lambda_imdb.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.allow_bucket]
}

# VPC
resource "aws_default_vpc" "default" {

}

resource "aws_default_subnet" "default_az1" {
  availability_zone = "${var.region}a"

  tags = {
    Name = "Default subnet for ${var.region}a"
  }
}

resource "aws_security_group" "lambda-sg" {
  vpc_id = aws_default_vpc.default.id

  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = 3306
    to_port = 3306
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "rds-sg" {
  vpc_id = aws_default_vpc.default.id

  ingress {
    protocol  = "tcp"
    from_port = 3306
    to_port   = 3306
    security_groups = [aws_security_group.lambda-sg.id]
  }

  egress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_default_vpc.default.id
  service_name = "com.amazonaws.${var.region}.s3"
  route_table_ids = [
    aws_default_vpc.default.default_route_table_id
  ]
}

resource "aws_vpc_endpoint" "sm" {
  vpc_id            = aws_default_vpc.default.id
  service_name      = "com.amazonaws.${var.region}.secretsmanager"
  vpc_endpoint_type = "Interface"

  security_group_ids = [
    aws_security_group.lambda-sg.id,
  ]

  subnet_ids = [
    aws_default_subnet.default_az1.id
  ]

  private_dns_enabled = true
}


# RDS
resource "aws_db_instance" "mysql_db" {
  allocated_storage           = 10
  db_name                     = "movie_data"
  engine                      = "mysql"
  vpc_security_group_ids = [aws_security_group.rds-sg.id]
  engine_version              = "8.0"
  instance_class              = "db.t2.micro"
  manage_master_user_password = true
  username                    = var.db_user
  skip_final_snapshot = true
}
