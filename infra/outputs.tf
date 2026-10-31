output "service_url" {
  description = "Offentlig URL til tjenesten"
  value       = aws_ecs_express_gateway_service.app.ingress_paths[0].endpoint
}

output "ingress_paths" {
  description = "Alle ingress paths, for feilsøking"
  value       = aws_ecs_express_gateway_service.app.ingress_paths
}

output "bucket_name" {
  value = aws_s3_bucket.images.bucket
}

output "task_role_arn" {
  value = aws_iam_role.task.arn
}

output "image_uri" {
  value = local.image_uri
}

output "dashboard_url" {
  value = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards/dashboard/${aws_cloudwatch_dashboard.main.dashboard_name}"
}
