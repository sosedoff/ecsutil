class ECSUtil::Commands::HelpCommand < ECSUtil::Command
  def run
    puts [
      "Usage: escutil <stage> <command>",
      "Available commands:",
      "* deploy  - Perform a deployment",
      "* run     - Run a task",
      "* scale   - Change service quantities",
      "* status  - Show current status",
      "* secrets - Manage secrets",
      "* destroy - Delete all cloud resources"
    ].join("\n")
  end
end