# How to Deploy Django Application to AWS ECS with Terraform?

## Information

In this project,I'll deploy a Django app to AWS EC2 with Docker. The app will run behind an HTTPS Nginx proxy.I'll use AWS RDS to serve our Postgres database along with AWS ECR to store and manage our Docker images.


By the end of this project, I'll be able to:

•Utilize the ECR Docker image registry to store images<br/>
•Create the required Terraform configuration for spinning up an ECS cluster<br/>
•Spin up AWS infrastructure via Terraform<br/>
•Deploy a Django app to a cluster of EC2 instances managed by an ECS Cluster<br/>
•Use Boto3 to update an ECS Service<br/>
•Configure AWS RDS for data persistence.<br/>
•Configure an AWS Security Group<br/>
•Deploy Django to AWS EC2 with Docker<br/>
•Run the Django app behind an HTTPS Nginx proxy<br/>

# Prerequisite:
•AWS  <br/>
•Terraform <br/>
•Docker <br/>
•Python v3.9.0 <br/>




**Terraform Modules**

Add a "terraform" folder to my project's root. I'll add each of our Terraform configuration files to this folder.
Here,I defined the AWS provider.I'll need to provide your AWS credentials in order to authenticate. Define them as environment variables:

```
$ AWS_ACCESS_KEY_ID="YOUR_AWS_ACCESS_KEY_ID"
$ AWS_SECRET_ACCESS_KEY="YOUR_AWS_SECRET_ACCESS_KEY"
```

After defining the credentials, I create the terraform modules.

•Networking<br/>
•VPC<br/>
•Public and private subnets<br/>
•Routing tables<br/>
•Internet Gateway<br/>
•Key Pairs<br/>
•Security Groups<br/>
•Load Balancers, Listeners, and Target Groups<br/>
•IAM Roles and Policies<br/>
•ECS<br/>
•Cluster<br/>
•Service<br/>
•Launch Config and Auto Scaling Group<br/>
•RDS<br/>

Next, add a new file to "terraform" called **provider.tf:**
```
provider "aws" {
  region = "eu-west-2"
}
```

Let's define our network resources in a new file called **network.tf:**
```
# VPC
resource "aws_vpc" "production-vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
}

# Public subnets
resource "aws_subnet" "public-subnet-1" {
  cidr_block        = var.public_subnet_1_cidr
  vpc_id            = aws_vpc.production-vpc.id
  availability_zone = var.availability_zones[0]
}
resource "aws_subnet" "public-subnet-2" {
  cidr_block        = var.public_subnet_2_cidr
  vpc_id            = aws_vpc.production-vpc.id
  availability_zone = var.availability_zones[1]
}

# Private subnets
resource "aws_subnet" "private-subnet-1" {
  cidr_block        = var.private_subnet_1_cidr
  vpc_id            = aws_vpc.production-vpc.id
  availability_zone = var.availability_zones[0]
}
resource "aws_subnet" "private-subnet-2" {
  cidr_block        = var.private_subnet_2_cidr
  vpc_id            = aws_vpc.production-vpc.id
  availability_zone = var.availability_zones[1]
}

# Route tables for the subnets
resource "aws_route_table" "public-route-table" {
  vpc_id = aws_vpc.production-vpc.id
}
resource "aws_route_table" "private-route-table" {
  vpc_id = aws_vpc.production-vpc.id
}

# Associate the new created route tables to the subnets
resource "aws_route_table_association" "public-route-1-association" {
  route_table_id = aws_route_table.public-route-table.id
  subnet_id      = aws_subnet.public-subnet-1.id
}
resource "aws_route_table_association" "public-route-2-association" {
  route_table_id = aws_route_table.public-route-table.id
  subnet_id      = aws_subnet.public-subnet-2.id
}
resource "aws_route_table_association" "private-route-1-association" {
  route_table_id = aws_route_table.private-route-table.id
  subnet_id      = aws_subnet.private-subnet-1.id
}
resource "aws_route_table_association" "private-route-2-association" {
  route_table_id = aws_route_table.private-route-table.id
  subnet_id      = aws_subnet.private-subnet-2.id
}

# Elastic IP
resource "aws_eip" "elastic-ip-for-nat-gw" {
  vpc                       = true
  associate_with_private_ip = "10.0.0.5"
  depends_on                = [aws_internet_gateway.production-igw]
}

# NAT gateway
resource "aws_nat_gateway" "nat-gw" {
  allocation_id = aws_eip.elastic-ip-for-nat-gw.id
  subnet_id     = aws_subnet.public-subnet-1.id
  depends_on    = [aws_eip.elastic-ip-for-nat-gw]
}
resource "aws_route" "nat-gw-route" {
  route_table_id         = aws_route_table.private-route-table.id
  nat_gateway_id         = aws_nat_gateway.nat-gw.id
  destination_cidr_block = "0.0.0.0/0"
}

# Internet Gateway for the public subnet
resource "aws_internet_gateway" "production-igw" {
  vpc_id = aws_vpc.production-vpc.id
}

# Route the public subnet traffic through the Internet Gateway
resource "aws_route" "public-internet-igw-route" {
  route_table_id         = aws_route_table.public-route-table.id
  gateway_id             = aws_internet_gateway.production-igw.id
  destination_cidr_block = "0.0.0.0/0"
}

```

Add the following variables as well:
```
# networking

variable "public_subnet_1_cidr" {
  description = "CIDR Block for Public Subnet 1"
  default     = "10.0.1.0/24"
}
variable "public_subnet_2_cidr" {
  description = "CIDR Block for Public Subnet 2"
  default     = "10.0.2.0/24"
}
variable "private_subnet_1_cidr" {
  description = "CIDR Block for Private Subnet 1"
  default     = "10.0.3.0/24"
}
variable "private_subnet_2_cidr" {
  description = "CIDR Block for Private Subnet 2"
  default     = "10.0.4.0/24"
}
variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["eu-west-2a", "eu-west-2b"]
}
```

Moving on, to protect the Django app and ECS cluster, let's configure Security Groups in a new file called **securitygroups.tf:**

```
# ALB Security Group (Traffic Internet -> ALB)
resource "aws_security_group" "load-balancer" {
  name        = "load_balancer_security_group"
  description = "Controls access to the ALB"
  vpc_id      = aws_vpc.production-vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
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

# ECS Security group (traffic ALB -> ECS, ssh -> ECS)
resource "aws_security_group" "ecs" {
  name        = "ecs_security_group"
  description = "Allows inbound access from ALB"
  vpc_id      = aws_vpc.production-vpc.id

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.load-balancer.id]
  }

  ingress {
    from_port   = 22
    to_port     = 22
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
```

Next, let's configure an **Application Load Balancer (ALB)** along with the appropriate Target Group and Listener.

```
# Production Load Balancer
resource "aws_lb" "production" {
  name               = "${var.ecs_cluster_name}-alb"
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.load-balancer.id]
  subnets            = [aws_subnet.public-subnet-1.id, aws_subnet.public-subnet-2.id]
}

# Target group
resource "aws_alb_target_group" "default-target-group" {
  name     = "${var.ecs_cluster_name}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.production-vpc.id

  health_check {
    path                = var.health_check_path
    port                = "traffic-port"
    healthy_threshold   = 5
    unhealthy_threshold = 2
    timeout             = 2
    interval            = 5
    matcher             = "100"
  }
}

# Listener (traffic from the load balancer to the target group)
resource "aws_alb_listener" "ecs-alb-http-listener" {
  load_balancer_arn = aws_lb.production.id
  port              = "80"
  protocol          = "HTTP"
  depends_on        = [aws_alb_target_group.default-target-group]

  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.default-target-group.arn
  }
}
```

Add the required variables:

```
# load balancer

variable "health_check_path" {
  description = "Health check path for the default target group"
  default     = "/ping/"
}

# ecs

variable "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  default     = "production"
}
```
I configured our load balancer and listener to listen for HTTP requests on port 80.After we verify that our infrastructure and application are set up correctly, I'll update the load balancer to listen for HTTPS requests on port 443.

Add the **iam.tf:**
```
resource "aws_iam_role" "AWSServiceRoleForECS" {
  name               = "AWSServiceRoleForECS"
  assume_role_policy = file("policies/assume-role-policy.json")
}

resource "aws_iam_role_policy" "AmazonECS_FullAccess" {
  name   = "AmazonECS_FullAccess"
  policy = file("policies/AmazonECS_FullAccess.json")
  role   = aws_iam_role.ecsInstanceRole.id
}


resource "aws_iam_instance_profile" "ecs-instance-role-django" {
  name = "ecs-instance-role-django"
  path = "/"
  role = aws_iam_role.ecs-instance-role-django.name
}
```
Add the **logs.tf:**
```
resource "aws_cloudwatch_log_group" "django-log-group" {
  name              = "/ecs/django-app"
  retention_in_days = var.log_retention_in_days
}

resource "aws_cloudwatch_log_stream" "django-log-stream" {
  name           = "django-app-log-stream"
  log_group_name = aws_cloudwatch_log_group.django-log-group.name
}
```
Add the variable:

```
# logs
variable "log_retention_in_days" {
  default = 20
}
```
Add the **keypair.tf:**

```
resource "aws_key_pair" "webapp" {
  key_name   = "${var.ecs_cluster_name}_key_pair"
  public_key = file(var.ssh_pubkey_file)
}
```

Variable:

```
# key pair
variable "ssh_pubkey_file" {
  description = "Path to an SSH public key"
  default     = "~/.ssh/id_rsa.pub"
}
```
Next step,We can configure **ecs.tf:**

```
resource "aws_ecs_cluster" "production" {
  name = "${var.ecs_cluster_name}-cluster"
}

resource "aws_launch_configuration" "ecs" {
  name                        = "${var.ecs_cluster_name}-cluster"
  image_id                    = lookup(var.amis, var.region)
  instance_type               = var.instance_type
  security_groups             = [aws_security_group.ecs.id]
  iam_instance_profile        = aws_iam_instance_profile.ecs.name
  key_name                    = aws_key_pair.production.key_name
  associate_public_ip_address = true
  user_data                   = "#!/bin/bash echo ECS_CLUSTER='${var.ecs_cluster_name}-cluster' > /etc/ecs/ecs.config"
}

data "template_file" "app" {
  template = file("templates/django_app.json.tpl")

  vars = {
    docker_image_url_django = var.docker_image_url_pyeditorial-app
    docker_image_url_nginx  = var.docker_image_url_nginx
    region                  = var.region
    rds_db_name             = var.rds_db_name
    rds_username            = var.rds_username
    rds_password            = var.rds_password
    rds_hostname            = aws_db_instance.production.address
    allowed_hosts           = var.allowed_hosts
  }
}

resource "aws_ecs_task_definition" "app" {
  family                = "django-app"
  container_definitions = data.template_file.app.rendered
  depends_on            = [aws_db_instance.production]

  volume {
    name      = "static_volume"
    host_path = "/usr/src/app/staticfiles/"
  }
}

resource "aws_ecs_service" "production" {
  name            = "${var.ecs_cluster_name}-service"
  cluster         = aws_ecs_cluster.production.id
  task_definition = aws_ecs_task_definition.app.arn
  iam_role        = aws_iam_role.ecs-service-role.arn
  desired_count   = var.app_count
  depends_on      = [aws_alb_listener.ecs-alb-http-listener, aws_iam_role_policy.ecs-service-role-policy]

  load_balancer {
    target_group_arn = aws_alb_target_group.default-target-group.arn
    container_name   = "nginx"
    container_port   = 80
  }
}
```

 ```user_data``` is a script that is run when a new EC2 instance is launched. In order for the ECS cluster to discover new EC2 instances, the cluster name needs to be added to the ECS_CLUSTER environment variable within the /etc/ecs/ecs.config config file within the instance.

Add a ```"templates"``` folder to the ```"terraform"``` folder, and then add a new template file called ```django.json.tpl:```

```
{
    "name": "PyEditorial",
    "image": "${docker_image_url_PyEditorial_web}",
    "essential": true,
    "cpu": 8,
    "memory": 216,
    "links": [],
    "portMappings": [
      {
        "containerPort": 8000,
        "hostPort": 0,
        "protocol": "tcp"
      }
    ],
    "command": ["gunicorn", "-w", "3", "-b", ":8000", "PyEditorial.wsgi:application"],
    "environment": [
      {
        "name": "RDS_DB_NAME",
        "value": "${rds_db_name}"
      },
      {
        "name": "RDS_USERNAME",
        "value": "${rds_username}"
      },
      {
        "name": "RDS_PASSWORD",
        "value": "${rds_password}"
      },
      {
        "name": "RDS_HOSTNAME",
        "value": "${rds_hostname}"
      },
      {
        "name": "RDS_PORT",
        "value": "5432"
      },
      {
        "name": "ALLOWED_HOSTS",
        "value": "${allowed_hosts}"
      }
    ],
    "mountPoints": [
      {
        "containerPath": "/usr/src/app/staticfiles",
        "sourceVolume": "static_volume"
      }
    ],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "/ecs/django-app",
        "awslogs-region": "${region}",
        "awslogs-stream-prefix": "django-app-log-stream"
      }
    }
```

Add the new logs to **logs.tf:**

```
resource "aws_cloudwatch_log_group" "nginx-log-group" {
  name              = "/ecs/nginx"
  retention_in_days = var.log_retention_in_days
}

resource "aws_cloudwatch_log_stream" "nginx-log-stream" {
  name           = "nginx-log-stream"
  log_group_name = aws_cloudwatch_log_group.nginx-log-group.name
}
```

Update the Service so it points to the **nginx** container instead of django-app:

```
resource "aws_ecs_service" "production" {
  name            = "${var.ecs_cluster_name}-service"
  cluster         = aws_ecs_cluster.production.id
  task_definition = aws_ecs_task_definition.app.arn
  iam_role        = aws_iam_role.ecs-service-role.arn
  desired_count   = var.app_count
  depends_on      = [aws_alb_listener.ecs-alb-http-listener, aws_iam_role_policy.ecs-service-role-policy]

  load_balancer {
    target_group_arn = aws_alb_target_group.default-target-group.arn
    container_name   = "nginx"
    container_port   = 80
  }
}
```

Now that we're dealing with two containers, let's update the deploy function to handle multiple container definitions in **update-ecs.py**

```
import boto3
import click


def get_current_task_definition(client, cluster, service):
    response = client.describe_services(cluster=cluster, services=[service])
    current_task_arn = response["services"][0]["taskDefinition"]

    response = client.describe_task_definition(taskDefinition=current_task_arn)
    return response


@click.command()
@click.option("--cluster", help="Name of the ECS cluster", required=True)
@click.option("--service", help="Name of the ECS service", required=True)
def deploy(cluster, service):
    client = boto3.client("ecs")

    container_definitions = []
    response = get_current_task_definition(client, cluster, service)
    for container_definition in response["taskDefinition"]["containerDefinitions"]:
        new_def = container_definition.copy()
        container_definitions.append(new_def)

    response = client.register_task_definition(
        family=response["taskDefinition"]["family"],
        volumes=response["taskDefinition"]["volumes"],
        containerDefinitions=container_definitions,
    )
    new_task_arn = response["taskDefinition"]["taskDefinitionArn"]

    response = client.update_service(
        cluster=cluster, service=service, taskDefinition=new_task_arn,
    )


if __name__ == "__main__":
    deploy()
```

Add the variable to the ECS section of the variables file, making sure to add your **domain name:**

```
variable "allowed_hosts" {
  description = "Domain name for allowed hosts"
  default     = "cloud59850.com"
}
```

**Finally, We need to run the below steps to test and create the infrastructure**

* `terraform init` is to initialize the working directory and downloading plugins of the AWS provider<br/>
* `terraform plan` is to create the execution plan for our code<br/>
* `terraform apply` is to create the actual infrastructure. It will ask you to provide the Access Key and Secret Key in order to create the infrastructure. So, instead of hardcoding the Access Key and Secret Key, it is better to apply at the run time.


For the next step,I created ECR,For push the Docker image to Elastic Container Registry (ECR), a private Docker image registry.


I reviewed [Docker Image - Amazon Elastic Container Registry](https://docs.aws.amazon.com/AmazonECS/latest/userguide/docker-basics.html.)

I'll following these steps.<br/>
I'll be using the ```eu-west-2``` region throughout this project.

```
aws ecr create-repository --repository-name pyeditorial-app --region eu-west-2
```
```
docker tag pyeditorial-app aws_account_id.dkr.ecr.eu-west-2.amazonaws.com/pyeditorial-app
```
```
aws ecr get-login-password | docker login --username AWS --password-stdin aws_account_id.dkr.ecr.eu-west-2.amazonaws.com
```
```
docker push aws_account_id.dkr.ecr.eu-west-2.amazonaws.com/pyeditorial-app
```
![ecr](https://github.com/nisaclk/aws-ecs-tf/blob/main/documentation/ecr-app.png)

Build the **Django** and **Nginx Docker images** and push them up to **ECR**:

```
$ cd app
$ docker build -t <AWS_ACCOUNT_ID>.dkr.ecr.us-west-1.amazonaws.com/django-app:latest .
$ docker push <AWS_ACCOUNT_ID>.dkr.ecr.us-west-1.amazonaws.com/django-app:latest
$ cd ..

$ cd nginx
$ docker build -t <AWS_ACCOUNT_ID>.dkr.ecr.eu-west-2.amazonaws.com/nginx:latest .
$ docker push <AWS_ACCOUNT_ID>.dkr.ecr.eu-west-2.amazonaws.com/nginx:latest
$ cd ..
```

Terraform will output an ALB domain. Create a CNAME record for this domain for the value in the allowed_hosts variable.
Open the EC2 instances overview page in AWS. Use ```ssh ec2-user@<ip>``` to connect to the instances until you find one for which docker ps contains the Django container. Run ```docker exec -it <container ID> python manage.py migrate.```


```
$ cd deploy
$ python ecs.py --cluster=production-cluster --service=production-service
```
Finally, when we run these commands, we expect the system to run.
