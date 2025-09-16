provider "aws" {
  region = "eu-west-3"
}

resource "aws_security_group" "vennela_sg" {
  name        = "vennela-sg"
  description = "Allow SSH, Jenkins, SonarQube, and Docker"
  vpc_id      = "vpc-0d1c5420a6c0c5f79"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Jenkins UI"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SonarQube UI"
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Jenkins Agent (JNLP)"
    from_port   = 50000
    to_port     = 50000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "vennela_instance" {
  ami                         = "ami-02d7ced41dff52ebc"
  instance_type               = "t3.large"
  subnet_id                   = "subnet-0448c551abe9d8da1"
  vpc_security_group_ids      = [aws_security_group.vennela_sg.id]
  key_name                    = "vvennela"
  associate_public_ip_address = true

  user_data = <<-EOF
    #!/bin/bash
    exec > /var/log/user-data.log 2>&1
    set -e

    echo "==== Updating system ===="
    apt-get update -y

    echo "==== Installing Java 17 ===="
    apt-get install -y openjdk-17-jdk unzip curl git nodejs npm docker.io

    echo "==== Enabling Docker service ===="
    systemctl enable docker
    systemctl start docker

    echo "==== Installing Jenkins ===="
    curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
    echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | tee /etc/apt/sources.list.d/jenkins.list
    apt-get update -y
    apt-get install -y jenkins
    systemctl enable jenkins
    systemctl start jenkins

    echo "==== Adding Jenkins to Docker group ===="
    usermod -aG docker jenkins
    newgrp docker

    echo "==== Pulling SonarQube Docker image ===="
    docker pull sonarqube:10.8.0-community

    echo "==== Running SonarQube container ===="
    docker run -d --name sonarqube \
      -p 9000:9000 \
      -e SONAR_ES_BOOTSTRAP_CHECKS_DISABLE=true \
      sonarqube:10.8.0-community

    echo "==== Setup complete! ===="
  EOF

  tags = {
    Name = "vennela-Jenkins-SonarQube-Server"
  }
}

output "jenkins_server_public_ip" {
  value = aws_instance.vennela_instance.public_ip
}