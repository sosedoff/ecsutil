class ECSUtil::Commands::DestroyCommand < ECSUtil::Command
  def run
    confirm "DANGER: You are about to deprovision all tasks and services! Proceed?"
    confirm "Are you absolutely sure?"

    config["tasks"]           = {}
    config["scheduled_tasks"] = {}
    config["services"]        = {}

    load_active_task_definitions
    load_secrets
    load_services

    deregister_tasks
    deregister_scheduled_tasks
    deregister_services
    deregister_secrets
  end
end