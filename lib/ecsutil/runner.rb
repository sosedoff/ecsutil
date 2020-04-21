require "ecsutil/config"
require "ecsutil/terraform"
require "ecsutil/shared"

require "ecsutil/commands/deploy"
require "ecsutil/commands/run"
require "ecsutil/commands/scale"
require "ecsutil/commands/secrets"
require "ecsutil/commands/status"
require "ecsutil/commands/destroy"

module ECSUtil
  class Runner
    include ECSUtil::Terraform

    def initialize(dir, args)
      stage         = args.shift
      command       = args.shift
      command_parts = command&.split(":", 2)
  
      @dir         = dir
      @stage       = stage
      @command     = command_parts&.shift
      @args        = args
      @action      = command_parts&.shift
      @config_path = File.join(@dir, "deploy", "#{stage}.yml")
    end

    def run
      return print_help unless @command
      return terminate("Please provide stage") unless @stage

      config = read_config

      case @command
      when nil, "help"
        print_help
      when "deploy"
        ECSUtil::Commands::DeployCommand.new(config, @action, @args).run
      when "run"
        ECSUtil::Commands::RunCommand.new(config, @action, @args).run
      when "scale"
        ECSUtil::Commands::ScaleCommand.new(config, @action, @args).run
      when "status"
        ECSUtil::Commands::StatusCommand.new(config, @action, @args).run
      when "secrets"
        ECSUtil::Commands::SecretsCommand.new(config, @action, @args).run
      when "destroy"
        ECSUtil::Commands::DestroyCommand.new(config, @action, @args).run
      else
        terminate "Invalid command: #{@command}"
        print_help
      end
    end

    private

    def print_help
      puts "Usage: escutil <stage> <command>"
      puts "Available commands:"
      puts "* deploy  - Perform a deployment"
      puts "* run     - Run a task"
      puts "* scale   - Change service quantities"
      puts "* status  - Show current status"
      puts "* secrets - Manage secrets"
      puts "* destroy - Delete all cloud resources"
    end

    def terminate(message)
      puts message
      exit 1
    end

    def read_config
      return nil unless @command && @stage

      outputs = {}
      terraform_dir = File.join(@dir, "terraform/#{@stage}")
      
      if File.exists?(terraform_dir)
        outputs = read_terraform_outputs(terraform_dir)
      else
        warn "No terraform found at #{terraform_dir}"
      end

      ECSUtil::Config.read(@config_path, @stage, outputs)
    end
  end
end