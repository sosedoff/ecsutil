# ecsutil

Tool to simplify deployments to ECS/Fargate

## Overview

- You bring your own infrastructure resources using Terraform (optional)
- `ecsutil` will manage ECS task definitions, scheduled tasks, services and secrets
- Deployment config is YAML-based with ability to reference Terraform outputs
- Cloud secrets are stored in AWS Parameter Store, encrypted by KMS
- Local secrets are encrypted via Ansible Vault

## Requirements

- AWS CLI
- Ansible (optional)
- Terraform (optional)

## Usage

```
Usage: escutil <stage> <command>

Available commands:
* deploy  - Perform a deployment
* run     - Run a task
* scale   - Change service quantities
* status  - Show current status
* secrets - Manage secrets
* destroy - Delete all cloud resources
```

## Config

Example deployment configuration:

```yaml
app: myapp
env: staging

cluster: staging
repository: your-ecr-repo-url
subnets:
  - a
  - b
  - c

roles:
  task: role ARN
  execution: role ARN
  schedule: role ARN

tasks:
  web:
    command: bundle exec ruby app.rb
    env:
      PORT: 4567
    security_groups:
      - sg1
      - sg2
    ports:
      - 4567
    awslogs:
      region: us-east-1
      group: myapp-staging
      prefix: web

scheduled_tasks:
  hourly:
    task: web
    command: bundle exec rake worker
    expression: rate(1 hour)

services:
  web:
    task: web
    desired_count: 3
    max_percent: 200
    min_healthy_percent: 100
    lb:
      target_group: load balancer target group ARN
      container_name: web
      container_port: 4567
```

### Reference Terraform outputs

Given you have `./terraform/(staging/production)`that contains all stage-specific
configuration and resources, you can add an output file `outputs.tf` that might be
referenced in the deployment config. Here's an example:

```tf
// Output for subnets
// YOu can use regular terraform resources here
output "subnets" {
  value = [
    "subnet-a",
    "subnet-b",
    "subnet-c"
  ]
}

// Output for "web" security group
output "sg_web" {
  value = aws_security_group.web.id
}
```

Once `terraform apply` is executed your state file (or remote state) will include 
the `sg_web` output. We can referene it in the config:

```yaml
# ...
subnets: $tf.subnets
# ....
tasks:
  web:
    security_groups: $tf.sg_web
```