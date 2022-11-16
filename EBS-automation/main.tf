terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }
  required_version = ">= 0.14.9"
}
# default profile
provider "aws" {
  profile = "default"
  region  = lookup(var.props, "region")
}
# loading policies json
data "local_file" "lambda_policy" {
  filename = "policy/policy.json"
}
# loading assumeRole json
data "local_file" "lambda_assumeRole_policy" {
  filename = "policy/assumeRole.json"
}

# lambda function
resource "aws_lambda_function" "function_ebs" {
  filename      = "code/index.zip"
  function_name = "automatic_ebs_snapshot"
  role          = aws_iam_role.lambda_assumeRole_policy.arn
  handler       = "index.lambda_handler"
  runtime       = "python3.9"
  environment {
    variables = {
        TAG_KEY = lookup(var.parameters,"tag_key"),
        TAG_VALUE = lookup(var.parameters,"tag_value")
    }
  }
  timeout = 600
  tags = var.tags
}

# iam role resource
resource "aws_iam_role" "lambda_assumeRole_policy" {
  name = "ebsSnapshotPolicy"
  assume_role_policy = data.local_file.lambda_assumeRole_policy.content
}

# iam policy resource
resource "aws_iam_role_policy" "pol" {
  name = "policy"
  role = aws_iam_role.lambda_assumeRole_policy.id
  policy = replace(data.local_file.lambda_policy.content, "ACCOUNT_ID", lookup(var.props,"account_id")) # substitue the account_id in policy.json for cloudwatch logs
}

# ----- EventBridge rule ----- 
resource "aws_cloudwatch_event_rule" "event_rule" {
  name        = "automatic_ebs_snapshot_rule"
  description = "Automatic rule for EBS snapshot creation"
  schedule_expression = lookup(var.schedule, "start")
  is_enabled = true
}
# ----- EventBridge target ----- 
resource "aws_cloudwatch_event_target" "target" {
  target_id = aws_lambda_function.function_ebs.id
  rule      = aws_cloudwatch_event_rule.event_rule.name
  arn       = aws_lambda_function.function_ebs.arn
}
# ----- Allow EventBridge to execute Lambda function ----- 
resource "aws_lambda_permission" "function_ebs_permission" {
  statement_id = "function_ebs_permission"
  action = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.function_ebs.function_name}"
  principal = "events.amazonaws.com"
  source_arn = "${aws_cloudwatch_event_rule.event_rule.arn}"
}