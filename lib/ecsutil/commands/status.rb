class ECSUtil::Commands::StatusCommand < ECSUtil::Command
  def run
    step_info "Fetching active task definitions..."
    active_task_definitions.each do |name|
      puts name
    end

    step_info "Fetching services..."
    fetch_active_services.each do |service|
      deployment = service["deployments"].first || {}

      printf(
        "%s STATUS=%s DESIRED=%d PENDING=%d RUNNING=%d\n",
        service["serviceName"],
        service["status"],
        deployment["desiredCount"],
        deployment["pendingCount"],
        deployment["runningCount"]
      )
    end
  end

  private

  def active_task_definitions
    list_active_task_definitions.select do |arn|
      arn.include?(config.namespace)
    end
  end

  def active_services
    list_services(config.cluster).select do |name|
      name.include?(config.namespace)
    end
  end

  def fetch_active_services
    names = active_services
    names.any? ? describe_services(config, names) : []
  end
end