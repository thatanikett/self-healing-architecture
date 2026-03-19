resource "aws_cloudwatch_metric_alarm" "smart_scale_out" {
  alarm_name          = "${var.project_name}-precision-scale-out"
  alarm_description   = "Scale out when CPU > 60 AND (Latency > 0.5s OR 5XX > 5)"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  threshold           = 1
  alarm_actions       = [aws_autoscaling_policy.scale_out.arn]

  metric_query {
    id          = "e1"
    expression  = "IF(m1 > 60 AND (m2 > 0.5 OR m3 > 5), 1, 0)"
    label       = "SmartScaleOutLogic"
    return_data = true
  }

  metric_query {
    id = "m1"
    metric {
      metric_name = "CPUUtilization"
      namespace   = "AWS/EC2"
      period      = 60
      stat        = "Average"
      dimensions = {
        AutoScalingGroupName = aws_autoscaling_group.app_asg.name
      }
    }
    return_data = false
  }

  metric_query {
    id = "m2"
    metric {
      metric_name = "TargetResponseTime"
      namespace   = "AWS/ApplicationELB"
      period      = 60
      stat        = "Average"
      dimensions = {
        LoadBalancer = aws_lb.app_alb.arn_suffix
        TargetGroup  = aws_lb_target_group.app_tg.arn_suffix
      }
    }
    return_data = false
  }

  metric_query {
    id = "m3"
    metric {
      metric_name = "HTTPCode_Target_5XX_Count"
      namespace   = "AWS/ApplicationELB"
      period      = 60
      stat        = "Sum"
      dimensions = {
        LoadBalancer = aws_lb.app_alb.arn_suffix
        TargetGroup  = aws_lb_target_group.app_tg.arn_suffix
      }
    }
    return_data = false
  }
}