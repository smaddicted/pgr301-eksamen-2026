data "aws_caller_identity" "current" {}

locals {
  name      = "wishifai-${var.candidate_number}"
  image_uri = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com/${local.name}:${var.image_tag}"

  # Rollene er gitt av emneansvarlig og skal ikke opprettes på nytt
  execution_role_arn      = "arn:aws:iam::244530008913:role/ecsTaskExecutionRole"
  infrastructure_role_arn = "arn:aws:iam::244530008913:role/service-role/ecsInfrastructureRoleForExpressServices"
}

# ---- S3-bucket for opplastede bilder ----

resource "aws_s3_bucket" "images" {
  bucket = "${local.name}-images"
}

# Bildene skal aldri være offentlig tilgjengelige
resource "aws_s3_bucket_public_access_block" "images" {
  bucket                  = aws_s3_bucket.images.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ---- Task role: rettighetene applikasjonen selv bruker ----

resource "aws_iam_role" "task" {
  name = "${local.name}-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "task" {
  name = "${local.name}-task-policy"
  role = aws_iam_role.task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # S3Service laster bare opp under uploads/ i egen bucket
        Sid      = "UploadImages"
        Effect   = "Allow"
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.images.arn}/uploads/*"
      },
      {
        # DetectLabels støtter ikke ressursnivå-tilgang, derfor "*"
        Sid      = "DetectLabels"
        Effect   = "Allow"
        Action   = "rekognition:DetectLabels"
        Resource = "*"
      },
      {
        # Converse-kallet krever InvokeModel på både inference profile og
        # selve modellen i regionene profilen kan rute til
        Sid    = "InvokeBedrock"
        Effect = "Allow"
        Action = "bedrock:InvokeModel"
        Resource = [
          "arn:aws:bedrock:${var.region}:${data.aws_caller_identity.current.account_id}:inference-profile/${var.bedrock_model_id}",
          "arn:aws:bedrock:*::foundation-model/${trimprefix(var.bedrock_model_id, "eu.")}"
        ]
      },
      {
        # MetricsConfig publiserer metrikker til CloudWatch (oppgave 3).
        # PutMetricData har ikke ressursnivå-tilgang, så tilgangen låses til egen namespace
        Sid      = "PublishMetrics"
        Effect   = "Allow"
        Action   = "cloudwatch:PutMetricData"
        Resource = "*"
        Condition = {
          StringEquals = { "cloudwatch:namespace" = local.name }
        }
      }
    ]
  })
}

# ---- Logger fra containeren ----

resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${local.name}"
  retention_in_days = 7
}

# ---- ECS Express-tjenesten ----

resource "aws_ecs_express_gateway_service" "app" {
  service_name            = local.name
  execution_role_arn      = local.execution_role_arn
  infrastructure_role_arn = local.infrastructure_role_arn
  task_role_arn           = aws_iam_role.task.arn

  # Standard er /ping, som applikasjonen ikke har
  health_check_path = "/actuator/health"

  # Standard 0,25 vCPU / 512 MiB er knapt for Spring Boot med AWS SDK
  cpu    = "512"
  memory = "1024"

  primary_container {
    image          = local.image_uri
    container_port = 8080

    aws_logs_configuration {
      log_group         = aws_cloudwatch_log_group.app.name
      log_stream_prefix = "app"
    }

    # Settes eksplisitt slik at alle AWS-klientene bruker samme region som bucketen
    environment {
      name  = "AWS_REGION"
      value = var.region
    }

    environment {
      name  = "S3_BUCKET"
      value = aws_s3_bucket.images.bucket
    }
  }
}
