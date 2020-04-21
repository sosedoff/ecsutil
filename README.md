# ecsutil

Tool to simplify deployments to ECS/Fargate. 

Key concepts:

- Infrastructure is managed by Terraform
- Task definitions/scheduled tasks/services are NOT part of Terraform
- YAML config for a service, ability to reference Terraform outputs
- Cloud secrets are stored in AWS Parameter Store, encrypted by KMS
- Local secrets are encrypted via Ansible Vault

Why not Kubernetes? You don't need Kube for simple deployments. 

## Requirements

- AWS CLI
- Ansible CLI

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