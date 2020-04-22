module ECSUtil
  module Shared
    def load_active_task_definitions
      step_info "Loading active task definitions"
      @existing_tasks = list_active_task_definitions
      @existing_tasks
    end

    def load_secrets
      step_info "Loading secrets from %s", config["secrets_prefix"]
      @config["secrets_data"] = fetch_parameter_store_keys(config["secrets_prefix"])
    end

    def load_services
      step_info "Loading services"
      @existing_services = list_services(config["cluster"])
    end

    def deregister_tasks
      @existing_tasks.each do |arn|
        step_info "Deregistering #{arn}"
        degerister_task_definition(arn)
      end
    end

    def deregister_scheduled_tasks
      prefix = sprintf("%s-%s", config["app"], config["env"])

      list_rules.each do |rule|
        next unless rule["Name"].start_with?(prefix)

        task_name = rule["Name"].sub(prefix + "-", "")
        next if config["scheduled_tasks"][task_name]
  
        step_info "Removing scheduled task: #{task_name}"
        delete_rule(rule["Name"])
      end
    end

    def deregister_services
      key          = sprintf("%s-%s", config["app"], config["env"])
      current_keys = config["services"].map do |k, _|
        sprintf("%s-%s", key, k)
      end
      
      @existing_services.each do |service|
        next unless service.start_with?(key)
        next if current_keys.include?(service)

        step_info "Deleting service: #{service}"
        delete_service(config, service)
      end
    end

    def deregister_secrets
      (config["secrets_data"] || []).each do |secret|
        step_info "Removing %s", secret[:name]
        aws_call("ssm", "delete-parameter", "--name=#{secret[:name]}")
      end
    end
  end
end