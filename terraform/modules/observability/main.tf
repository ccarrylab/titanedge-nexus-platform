resource "aws_cloudwatch_log_group" "platform" {
  name              = "/atlasrelay/platform"
  retention_in_days = 30
}
