# Alarm 1: High 5XX Errors from Targets
resource "aws_cloudwatch_metric_alarm" "target_5xx_errors" {
  alarm_name          = "${var.project_name}-target-5xx-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 5 # More than 5 errors in a minute

  dimensions = {
    LoadBalancer = aws_lb.app_alb.arn_suffix
    TargetGroup  = aws_lb_target_group.app_tg.arn_suffix
  }
}

# Alarm 2: High Response Latency
resource "aws_cloudwatch_metric_alarm" "high_latency" {
  alarm_name          = "${var.project_name}-high-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 0.5 # 500ms response time

  dimensions = {
    LoadBalancer = aws_lb.app_alb.arn_suffix
    TargetGroup  = aws_lb_target_group.app_tg.arn_suffix
  }
}

resource "aws_cloudwatch_composite_alarm" "smart_scale_out" {
  alarm_name        = "${var.project_name}-precision-scale-out"
  alarm_description = "Scale out only when high CPU impacts user experience"

  # Logic: CPU High AND (Latency High OR 5XX Errors)
  alarm_rule = "ALARM(${aws_cloudwatch_metric_alarm.cpu_high.alarm_name}) AND (ALARM(${aws_cloudwatch_metric_alarm.high_latency.alarm_name}) OR ALARM(${aws_cloudwatch_metric_alarm.target_5xx_errors.alarm_name}))"

  # This now triggers the scaling policy
  alarm_actions = [aws_autoscaling_policy.scale_out.arn]
}