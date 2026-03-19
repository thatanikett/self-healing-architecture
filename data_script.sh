#!/bin/bash
set -e

# 1. Install dependencies and CloudWatch Agent
yum update -y
yum install -y git python3 python3-pip nginx amazon-cloudwatch-agent

# 2. Configure CloudWatch Agent to track Nginx and Flask logs
mkdir -p /opt/aws/amazon-cloudwatch-agent/etc/
cat <<EOF > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
{
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/nginx/access.log",
            "log_group_name": "testWebsite/nginx-access",
            "log_stream_name": "{instance_id}"
          },
          {
            "file_path": "/home/ec2-user/testWebsite/app.log",
            "log_group_name": "testWebsite/flask-app",
            "log_stream_name": "{instance_id}"
          }
        ]
      }
    }
  }
}
EOF

# 3. Start CloudWatch Agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

# 4. Clone testWebsite app
cd /home/ec2-user
git clone https://github.com/thatanikett/testWebsite.git
chown -R ec2-user:ec2-user /home/ec2-user/testWebsite

# 5. Setup Python Environment
cd /home/ec2-user/testWebsite
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt gunicorn

# 6. Create systemd service for testWebsite
cat <<EOF > /etc/systemd/system/testWebsite.service
[Unit]
Description=Gunicorn instance for testWebsite
After=network.target

[Service]
User=ec2-user
Group=ec2-user
WorkingDirectory=/home/ec2-user/testWebsite
# We redirect output to app.log so the CW Agent can pick it up
ExecStart=/home/ec2-user/testWebsite/venv/bin/gunicorn --workers 2 --bind 127.0.0.1:5000 app:app --access-logfile /home/ec2-user/testWebsite/app.log
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# 7. Start Services
systemctl daemon-reload
systemctl enable nginx testWebsite
systemctl start testWebsite

# 8. Configure Nginx Proxy
cat <<EOF > /etc/nginx/conf.d/testWebsite.conf
server {
    listen 80;
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

systemctl restart nginx