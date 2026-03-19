# Log Group for Application Logs
resource "aws_cloudwatch_log_group" "flask_app_logs" {
  name              = "testWebsite/flask-app"
  retention_in_days = 7 
}

# Log Group for Nginx Access Logs
resource "aws_cloudwatch_log_group" "nginx_access_logs" {
  name              = "testWebsite/nginx-access"
  retention_in_days = 7
}