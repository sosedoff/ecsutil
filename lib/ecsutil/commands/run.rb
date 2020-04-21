class ECSUtil::Commands::RunCommand < ECSUtil::Command
  def run
    task_name = args.shift
    terminate("Task name is required") unless task_name

    task   = config["tasks"][task_name]
    family = sprintf("%s-%s-%s", config["app"], config["env"], task_name)

    arn = load_active_task_definitions.find do |task_arn|
      task_arn.split("/", 2).last.start_with?(family)
    end

    if !arn
      terminate "Cant find task definition for #{family}"
    end

    opts = {
      startedBy: `whoami`.strip,
      cluster: config["cluster"],
      taskDefinition: arn,
      launchType: "FARGATE",
      networkConfiguration: {
        awsvpcConfiguration: {
          subnets: config["subnets"],
          securityGroups: [task["security_groups"]].flatten,
          "assignPublicIp": "ENABLED"
        }
      }
    }
    
    if args && args.any?
      step_info "Using override command: #{args}"

      opts[:overrides] = {
        containerOverrides: [
          {
            name: task_name,
            command: args,
          }
        ]
      }
    end

    step_info "Running task using #{arn}"
    aws_call("ecs", "run-task", opts)
  end
end