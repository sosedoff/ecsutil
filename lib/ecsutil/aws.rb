module ECSUtil
  module AWS
    def aws_call(service, method, data)
      input = data.is_a?(String) ? data : "--cli-input-json file://#{json_file(data)}" 

      result = `aws #{service} #{method} #{input}`.strip
      unless $?.success?
        fail "#{service} #{method} failed!"
      end
      JSON.load(result)
    end

    def generate_event_rule(config)
      {
        Name:               config[:name],
        ScheduleExpression: config[:expression],
        State:              config[:enabled] ? "ENABLED" : "DISABLED",
        Tags:               array_hash(config[:tags] || {}, "Key", "Value")
      }
    end

    def generate_event_target(config, task_name, schedule_name)
      task     = config["tasks"][task_name]
      schedule = config["scheduled_tasks"][schedule_name]
      input    = {}

      if schedule["command"]
        input = {
          "containerOverrides": [
            {
              "name": task_name,
              "command": schedule["command"].split(" ")
            }
          ]
        }
      end

      {
        Rule: schedule["rule_name"],
        Targets: [
          {
            Id: "default",
            Arn: config["cluster"],
            RoleArn: config["roles"]["schedule"],
            Input: JSON.dump(input),
            EcsParameters: {
              TaskDefinitionArn: task["arn"],
              TaskCount: 1,
              LaunchType: "FARGATE",
              PlatformVersion: "LATEST",
              NetworkConfiguration: {
                awsvpcConfiguration: {
                  Subnets: [config["subnets"]].flatten,
                  SecurityGroups: [task["security_groups"]].flatten,
                  AssignPublicIp: "ENABLED"
                }
              }
            }
          }
        ]
      }
    end

    def generate_task_definition(config, task_name)
      task         = config["tasks"][task_name]
      service_name = config["app"]
      service_env  = config["env"]
      env          = array_hash(task["env"] || {}, :name)

      secrets = (config["secrets_data"] || []).map do |item|
        {
          name:      item[:key],
          valueFrom: item[:name]
        }
      end

      log_config = nil

      if awslogs = task["awslogs"]
        log_config = {
          logDriver: "awslogs",
          options: {
            "awslogs-group": awslogs["group"],
            "awslogs-region": awslogs["region"],
            "awslogs-stream-prefix": awslogs["prefix"] || task_name
          }
        }
      end

      if sumo = task["sumologs"]
        log_config = {
          logDriver: "splunk",
          options: {
            "splunk-url":        sumo["url"],
            "splunk-token":      sumo["token"],
            "splunk-source":     sumo["source"] || "",
            "splunk-sourcetype": sumo["sourcetype"] || "",
          }
        }
      end

      port_mappings = nil
      if ports = [task["ports"]].flatten.compact.uniq
        port_mappings = ports.map do |p|
          {
            containerPort: p,
            hostPort: p,
            protocol: "tcp"
          }
        end
      end

      image = config["repository"].to_s
      unless image.split("/").last.include?(":")
        image << ":#{config["git_commit"]}"
      end

      {
        family: "#{service_name}-#{service_env}-#{task_name}",
        taskRoleArn: config["roles"]["task"],
        executionRoleArn: config["roles"]["execution"],
        networkMode: "awsvpc",
        requiresCompatibilities: ["FARGATE"],
        cpu: (task["cpu"] || "256").to_s,
        memory: (task["memory"] || "512").to_s,
        containerDefinitions: [
          {
            name: task_name,
            command: task["command"] ? task["command"].split(" ") : nil,
            image: image,
            environment: env,
            secrets: secrets,
            logConfiguration: log_config,
            portMappings: port_mappings
          }.compact
        ]
      }
    end

    def degerister_task_definition(arn)
      aws_call("ecs", "deregister-task-definition", "--task-definition #{arn}")
    end

    def register_task_definition(data)
      aws_call("ecs", "register-task-definition", data)["taskDefinition"]
    end

    def put_rule(data)
      aws_call("events", "put-rule", data)
    end

    def put_targets(data)
      aws_call("events", "put-targets", data)
    end

    def delete_rule(name)
      aws_call("events", "remove-targets", "--rule=#{name} --ids=default")
      aws_call("events", "delete-rule", "--name=#{name}")
    end

    def list_active_task_definitions
      aws_call("ecs", "list-task-definitions", "--status=ACTIVE --max-items=100")["taskDefinitionArns"]
    end

    def list_services(cluster)
      aws_call("ecs", "list-services", "--cluster=#{cluster}")["serviceArns"].map do |s|
        s.split("/", 3).last
      end
    end

    def list_rules
      aws_call("events", "list-rules", "")["Rules"]
    end

    def fetch_parameter_store_keys(prefix, process = true)
      result = aws_call("ssm", "get-parameters-by-path", "--path=#{prefix} --with-decryption")
      result["Parameters"].map do |p|
        {
          name: p["Name"],
          key: p["Name"].split("/").last,
          value: p["Value"]
        }
      end
    end

    def generate_service(config, service_name)
      service           = config["services"][service_name]
      task              = config["tasks"][service["task"]]
      full_service_name = sprintf("%s-%s-%s", config["app"], config["env"], service_name)
      exists            = service["exists"] == true

      data = {
        cluster: config["cluster"],
        taskDefinition: task["arn"],
        desiredCount: service["desired_count"] || 0,
        deploymentConfiguration: {
          maximumPercent: service["max_percent"] || 100,
          minimumHealthyPercent: service["min_healthy_percent"] || 50
        },
        networkConfiguration: {
          awsvpcConfiguration: {
            subnets: [config["subnets"]].flatten,
            securityGroups: [task["security_groups"]].flatten,
            assignPublicIp: "ENABLED"
          }
        }
      }

      if exists
        data.merge!(
          service: full_service_name,
          forceNewDeployment: service["force_deployment"] == true
        )
      else
        data.merge!(
          serviceName: full_service_name,
          propagateTags: "SERVICE",
          enableECSManagedTags: true,
          schedulingStrategy: "REPLICA",
          launchType: "FARGATE",
        )

        if lb = service["lb"]
          data.merge!(
            loadBalancers: [
              {
                targetGroupArn:   lb["target_group"],
                loadBalancerName: lb["name"],
                containerName:    lb["container_name"],
                containerPort:    lb["container_port"]
              }.compact
            ]
          )
        end
      end
      
      data
    end

    def describe_service(config, service_name)
      full_service_name = sprintf("%s-%s-%s", config["app"], config["env"], service_name)
      result = aws_call("ecs", "describe-services", "--cluster=#{config["cluster"]} --services=#{full_service_name}")
      result["services"].first
    end

    def describe_services(config, names)
      aws_call("ecs", "describe-services", "--cluster=#{config.cluster} --services=#{names.join(",")}")["services"]
    end

    def create_service(config, service_name)
      aws_call("ecs", "create-service", generate_service(config, service_name))
    end

    def update_service(config, service_name)
      aws_call("ecs", "update-service", generate_service(config, service_name))
    end

    def delete_service(config, service_name)
      aws_call("ecs", "update-service", "--cluster=#{config["cluster"]} --service=#{service_name} --desired-count 0")
      aws_call("ecs", "delete-service", "--cluster=#{config["cluster"]} --service=#{service_name}")
    end
  end
end
