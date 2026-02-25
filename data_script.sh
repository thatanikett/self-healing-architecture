#!/bin/bash
set -e

# Install dependencies
yum install -y git python3 python3-pip nginx

# Enable nginx
systemctl enable nginx

# Clone app
cd /home/ec2-user
git clone https://github.com/thatanikett/testwebapp.git app
chown -R ec2-user:ec2-user /home/ec2-user/app

# Setup Python
cd /home/ec2-user/app
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

# Ensure gunicorn exists
pip install gunicorn

# Create systemd service
cat <<EOF > /etc/systemd/system/testwebapp.service
[Unit]
Description=Gunicorn instance
After=network.target

[Service]
User=ec2-user
Group=ec2-user
WorkingDirectory=/home/ec2-user/app
ExecStart=/home/ec2-user/app/venv/bin/gunicorn --workers 2 --bind 127.0.0.1:5000 app:app
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Start app
systemctl daemon-reload
systemctl enable testwebapp
systemctl start testwebapp

# Configure nginx
cat <<EOF > /etc/nginx/conf.d/testwebapp.conf
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