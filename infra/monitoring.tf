locals {
  ns          = local.name
  ecs_dims    = ["ClusterName", "default", "ServiceName", local.name]
  ms_axis     = { left = { label = "ms", showUnits = false } }
  pct_axis    = { left = { min = 0, max = 100, label = "%", showUnits = false } }
  header_size = { width = 24, height = 1 }
}

# ---- Dashboard ----

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = local.name

  dashboard_body = jsonencode({
    widgets = [
      # Business: hva brukerne gjør og hva de får tilbake
      merge(local.header_size, { type = "text", x = 0, y = 0, properties = { markdown = "## Business" } }),
      {
        type = "metric", x = 0, y = 1, width = 8, height = 6
        properties = {
          title  = "Analyserte bilder per romtype"
          region = var.region, view = "timeSeries", stacked = true, period = 300
          metrics = [[{
            expression = "SEARCH('Namespace=\"${local.ns}\" MetricName=\"wishifai.images.analyzed.count\"', 'Sum', 300)"
            id         = "rooms"
          }]]
        }
      },
      {
        type = "metric", x = 8, y = 1, width = 8, height = 6
        properties = {
          title   = "Gaveforslag per analyse (snitt)"
          region  = var.region, view = "timeSeries", period = 300
          metrics = [[local.ns, "wishifai.suggestions.per.analysis.avg", { stat = "Average", label = "Forslag per bilde" }]]
          yAxis   = { left = { min = 0 } }
        }
      },
      {
        type = "metric", x = 16, y = 1, width = 8, height = 6
        properties = {
          title   = "Bedrock-svar som ikke kunne tolkes"
          region  = var.region, view = "timeSeries", period = 300
          metrics = [[local.ns, "wishifai.bedrock.parse.failures.count", { stat = "Sum", label = "Parse-feil" }]]
          yAxis   = { left = { min = 0 } }
        }
      },

      # Applikasjon: hvor tiden blir av
      merge(local.header_size, { type = "text", x = 0, y = 7, properties = { markdown = "## Applikasjon" } }),
      {
        type = "metric", x = 0, y = 8, width = 12, height = 6
        properties = {
          title  = "Svartid: Rekognition vs. Bedrock"
          region = var.region, view = "timeSeries", period = 60
          metrics = [
            [local.ns, "wishifai.rekognition.duration.avg", { stat = "Average", label = "Rekognition snitt" }],
            [local.ns, "wishifai.bedrock.duration.avg", { stat = "Average", label = "Bedrock snitt" }],
            [local.ns, "wishifai.bedrock.duration.max", { stat = "Maximum", label = "Bedrock maks" }]
          ]
          yAxis       = local.ms_axis
          annotations = { horizontal = [{ label = "Alarmgrense", value = var.bedrock_latency_threshold_ms }] }
        }
      },
      {
        type = "metric", x = 12, y = 8, width = 12, height = 6
        properties = {
          title  = "HTTP /api/analyze: total svartid (Actuator)"
          region = var.region, view = "timeSeries", period = 60
          metrics = [[{
            expression = "SEARCH('Namespace=\"${local.ns}\" MetricName=\"http.server.requests.avg\" uri=\"/api/analyze\"', 'Average', 60)"
            id         = "http"
          }]]
          yAxis = local.ms_axis
        }
      },
      {
        type = "metric", x = 0, y = 14, width = 12, height = 6
        properties = {
          title  = "JVM heap brukt (Actuator)"
          region = var.region, view = "timeSeries", stacked = true, period = 60
          metrics = [[{
            expression = "SEARCH('Namespace=\"${local.ns}\" MetricName=\"jvm.memory.used.value\" area=\"heap\"', 'Average', 60)"
            id         = "heap"
          }]]
        }
      },
      {
        type = "metric", x = 12, y = 14, width = 12, height = 6
        properties = {
          title  = "GC-pauser (Actuator)"
          region = var.region, view = "timeSeries", period = 60
          metrics = [[{
            expression = "SEARCH('Namespace=\"${local.ns}\" MetricName=\"jvm.gc.pause.max\"', 'Maximum', 60)"
            id         = "gc"
          }]]
          yAxis = local.ms_axis
        }
      },

      # Infrastruktur: ECS Express
      merge(local.header_size, { type = "text", x = 0, y = 20, properties = { markdown = "## Infrastruktur (ECS)" } }),
      {
        type = "metric", x = 0, y = 21, width = 12, height = 6
        properties = {
          title  = "CPU og minne"
          region = var.region, view = "timeSeries", period = 60
          metrics = [
            concat(["AWS/ECS", "CPUUtilization"], local.ecs_dims, [{ stat = "Average", label = "CPU" }]),
            concat(["AWS/ECS", "MemoryUtilization"], local.ecs_dims, [{ stat = "Average", label = "Minne" }])
          ]
          yAxis = local.pct_axis
        }
      },
      {
        type = "metric", x = 12, y = 21, width = 12, height = 6
        properties = {
          title   = "Kjørende tasks"
          region  = var.region, view = "timeSeries", period = 60
          metrics = [concat(["AWS/ECS", "LiveTaskCount"], local.ecs_dims, [{ stat = "Average", label = "Tasks" }])]
          yAxis   = { left = { min = 0 } }
        }
      }
    ]
  })
}

# ---- Varsling ----

resource "aws_sns_topic" "alarms" {
  name = "${local.name}-alarms"
}

# E-post settes som GitHub-variabel
resource "aws_sns_topic_subscription" "email" {
  count     = var.alarm_email == "" ? 0 : 1
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

# ---- Alarmer ----

# Oversikt over treg tjeneste (Bedrock)
resource "aws_cloudwatch_metric_alarm" "bedrock_latency" {
  alarm_name          = "${local.name}-bedrock-latency"
  alarm_description   = "Snittlig svartid mot Bedrock over ${var.bedrock_latency_threshold_ms} ms i 3 av 5 minutter"
  namespace           = local.ns
  metric_name         = "wishifai.bedrock.duration.avg"
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 5
  datapoints_to_alarm = 3
  threshold           = var.bedrock_latency_threshold_ms
  comparison_operator = "GreaterThanThreshold"
  # Ingen trafikk betyr ingen målinger, og det er ikke en feil
  treat_missing_data = "notBreaching"
  alarm_actions      = [aws_sns_topic.alarms.arn]
  ok_actions         = [aws_sns_topic.alarms.arn]
}

# Fanger svar som er vellykkede (HTTP 200), men ubrukelige for brukeren
resource "aws_cloudwatch_metric_alarm" "bedrock_parse_failures" {
  alarm_name          = "${local.name}-bedrock-parse-failures"
  alarm_description   = "Bedrock har returnert svar som ikke kunne tolkes som JSON"
  namespace           = local.ns
  metric_name         = "wishifai.bedrock.parse.failures.count"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]
}
