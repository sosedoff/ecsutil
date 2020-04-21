class ECSUtil::Commands::ScaleCommand < ECSUtil::Command
  def run
    services = config["services"] || {}
    terminate("No services found") if services.empty?

    services.each_pair do |service_name, service|
      info = describe_service(config, service_name)
      service["exists"] = true
      config["tasks"][service["task"]]["arn"] = info["taskDefinition"]

      if info["runningCount"] != service["desired_count"]
        step_info "Scaling #{service_name} from %d to %d",
          info["runningCount"],
          service["desired_count"]

        update_service(config, service_name)
      else
        step_info "Scaling is skipped on #{service_name}. Requested: %d, actual %d",
          service["desired_count"],
          info["runningCount"]
      end
    end
  end
end