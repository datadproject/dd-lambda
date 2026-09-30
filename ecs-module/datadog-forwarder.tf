###############################################################################
# OPTIONAL DATADOG CLOUDWATCH LOG FORWARDER
# ECS -> awslogs -> CloudWatch Logs -> Datadog Forwarder Lambda -> Datadog
###############################################################################

data "aws_partition" "dd_forwarder" {}
data "aws_caller_identity" "dd_forwarder" {}

data "aws_secretsmanager_secret" "dd_forwarder_api_key" {
  count = var.dd_forwarder_enabled ? 1 : 0
  name  = var.dd_api_key_secret_name
}

locals {
  dd_forwarder_function_name = substr("fatw-${var.environment_tag}-datadog-forwarder", 0, 64)

  dd_forwarder_layer_arn = format(
    "arn:%s:lambda:%s:002406178527:layer:Datadog-Forwarder:%s",
    data.aws_partition.dd_forwarder.partition,
    var.region,
    var.dd_forwarder_layer_version
  )

  dd_forwarder_auto_log_groups = toset(compact([
    for td_name, config in var.datadog_tasks :
    try(var.ecs_task_definition[td_name].awslogs_group, null)
  ]))

  dd_forwarder_target_log_groups = var.dd_forwarder_enabled ? (
    length(var.dd_forwarder_log_groups) > 0
    ? var.dd_forwarder_log_groups
    : local.dd_forwarder_auto_log_groups
  ) : toset([])
}

data "archive_file" "dd_forwarder_placeholder" {
  count       = var.dd_forwarder_enabled ? 1 : 0
  type        = "zip"
  output_path = "${path.root}/datadog-forwarder-placeholder.zip"

  source {
    filename = "placeholder.txt"
    content  = "Datadog Forwarder code is supplied by the Lambda layer."
  }
}

resource "aws_iam_role" "dd_forwarder" {
  count = var.dd_forwarder_enabled ? 1 : 0
  name  = "${local.dd_forwarder_function_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })

  tags = merge(local.common_tags, { Name = "${local.dd_forwarder_function_name}-role" })
}

resource "aws_iam_role_policy_attachment" "dd_forwarder_basic" {
  count = var.dd_forwarder_enabled ? 1 : 0
  role  = aws_iam_role.dd_forwarder[0].name
  policy_arn = format(
    "arn:%s:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
    data.aws_partition.dd_forwarder.partition
  )
}

resource "aws_iam_role_policy_attachment" "dd_forwarder_vpc" {
  count = var.dd_forwarder_enabled ? 1 : 0
  role  = aws_iam_role.dd_forwarder[0].name
  policy_arn = format(
    "arn:%s:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole",
    data.aws_partition.dd_forwarder.partition
  )
}

resource "aws_iam_role_policy" "dd_forwarder_secret" {
  count = var.dd_forwarder_enabled ? 1 : 0
  name  = "${local.dd_forwarder_function_name}-secret-access"
  role  = aws_iam_role.dd_forwarder[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "ReadDatadogApiKey"
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = [data.aws_secretsmanager_secret.dd_forwarder_api_key[0].arn]
    }]
  })
}

resource "aws_lambda_function" "dd_forwarder" {
  count         = var.dd_forwarder_enabled ? 1 : 0
  function_name = local.dd_forwarder_function_name
  description   = "Forwards ECS CloudWatch logs to Datadog"
  role          = aws_iam_role.dd_forwarder[0].arn
  runtime       = "python3.13"
  handler       = "lambda_function.lambda_handler"
  architectures = ["arm64"]

  filename         = data.archive_file.dd_forwarder_placeholder[0].output_path
  source_code_hash = data.archive_file.dd_forwarder_placeholder[0].output_base64sha256
  layers           = [local.dd_forwarder_layer_arn]

  memory_size = var.dd_forwarder_memory_size
  timeout     = var.dd_forwarder_timeout

  vpc_config {
    subnet_ids         = var.dd_forwarder_subnet_ids
    security_group_ids = var.dd_forwarder_security_group_ids
  }

  environment {
    variables = {
      DD_SITE                      = var.dd_site
      DD_API_KEY_SECRET_ARN        = data.aws_secretsmanager_secret.dd_forwarder_api_key[0].arn
      DD_FORWARD_LOG               = "true"
      DD_TRACE_ENABLED             = "false"
      DD_ENHANCED_METRICS          = "false"
      DD_USE_VPC                   = "true"
      DD_TAGS                      = "env:${var.environment_tag}"
      DD_FETCH_LAMBDA_TAGS         = "false"
      DD_FETCH_LOG_GROUP_TAGS      = "false"
      DD_FETCH_S3_TAGS             = "false"
      DD_FETCH_STEP_FUNCTIONS_TAGS = "false"
      DD_STORE_FAILED_EVENTS       = "false"
      DD_TAGS_CACHE_TTL_SECONDS    = "300"
      HTTP_PROXY                   = var.dd_proxy_https
      HTTPS_PROXY                  = var.dd_proxy_https
      NO_PROXY                     = join(",", var.dd_proxy_no_proxy)
      DD_SKIP_SSL_VALIDATION       = tostring(var.dd_forwarder_skip_ssl_validation)
      DD_LOG_LEVEL                 = "INFO"
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.dd_forwarder_basic,
    aws_iam_role_policy_attachment.dd_forwarder_vpc,
    aws_iam_role_policy.dd_forwarder_secret
  ]

  tags = merge(local.common_tags, { Name = local.dd_forwarder_function_name })
}

resource "aws_cloudwatch_log_group" "dd_forwarder" {
  count             = var.dd_forwarder_enabled ? 1 : 0
  name              = "/aws/lambda/${local.dd_forwarder_function_name}"
  retention_in_days = var.dd_forwarder_log_retention_days
  tags              = merge(local.common_tags, { Name = local.dd_forwarder_function_name })
}

resource "aws_lambda_permission" "dd_forwarder_cloudwatch" {
  count          = var.dd_forwarder_enabled ? 1 : 0
  statement_id   = "CloudWatchLogsInvokePermission"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.dd_forwarder[0].function_name
  principal      = "logs.amazonaws.com"
  source_account = var.account_id
  source_arn = format(
    "arn:%s:logs:%s:%s:log-group:*:*",
    data.aws_partition.dd_forwarder.partition,
    var.region,
    var.account_id
  )
}

resource "aws_cloudwatch_log_subscription_filter" "dd_forwarder" {
  for_each        = local.dd_forwarder_target_log_groups
  name            = "datadog-forwarder"
  log_group_name  = each.value
  filter_pattern  = ""
  destination_arn = aws_lambda_function.dd_forwarder[0].arn

  depends_on = [aws_lambda_permission.dd_forwarder_cloudwatch]
}
