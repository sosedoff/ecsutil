class ECSUtil::Commands::DeployCommand < ECSUtil::Command
  def run
    confirm

    load_active_task_definitions
    load_secrets
    load_services

    register_tasks
    register_scheduled_tasks
    register_services

    deregister_tasks
    deregister_scheduled_tasks
    deregister_services
  end

  protected

  def register_tasks
    config["tasks"].each_pair do |name, task_config|
      step_info "Registering task definition: #{name}"
      task_def = generate_task_definition(config, name)
      result   = register_task_definition(task_def)
      arn      = result["taskDefinitionArn"]

      config["tasks"][name]["arn"] = arn
      step_info "Registered #{name}: #{arn}"
    end
  end

  def register_scheduled_tasks
    config["scheduled_tasks"].each_pair do |name, schedule|
      step_info "Creating event rule for #{name}"

      task      = config["tasks"][schedule["task"]]
      rule_name = sprintf("%s-%s-%s", config["app"], config["env"], name)
      rule_exp  = schedule["expression"]

      rule_data = generate_event_rule(
        name:       rule_name,
        expression: rule_exp,
        enabled:    schedule.key?("enabled") ? schedule["enabled"] == true : true
      )

      result = put_rule(rule_data)
      config["scheduled_tasks"][name]["rule_name"] = rule_name
      config["scheduled_tasks"][name]["rule_arn"] = result["RuleArn"]

      step_info "Creating event target for #{name}"
      rule_targets = generate_event_target(config, schedule["task"], name)
      put_targets(rule_targets)
    end

    def register_services
      config["services"].each_pair do |service_name, service|
        full_name = sprintf("%s-%s-%s", config["app"], config["env"], service_name)
        service["exists"] = @existing_services.include?(full_name)
  
        if service["exists"]
          step_info "Updating service #{service_name}"
          update_service(config, service_name)
        else
          step_info "Creating service #{service_name}"
          create_service(config, service_name)
        end
      end
    end
  end
end