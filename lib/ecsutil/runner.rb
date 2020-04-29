require "ecsutil/config"
require "ecsutil/terraform"
require "ecsutil/shared"

require "ecsutil/commands/help"
require "ecsutil/commands/init"
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
      
      klass = command_class(@command)
      if !klass
        terminate "Invalid command: #{@command}"
      end

      klass.new(config, @action, @args).run
    end

    private

    def command_class(name = "help")
      {
        help:    ECSUtil::Commands::HelpCommand,
        init:    ECSUtil::Commands::InitCommand,
        deploy:  ECSUtil::Commands::DeployCommand,
        run:     ECSUtil::Commands::RunCommand,
        scale:   ECSUtil::Commands::ScaleCommand,
        status:  ECSUtil::Commands::StatusCommand,
        secrets: ECSUtil::Commands::SecretsCommand,
        destroy: ECSUtil::Commands::DestroyCommand,
      }[name.to_sym]
    end

    def terminate(message)
      puts message
      exit 1
    end

    def read_config
      return nil unless @command && @stage

      outputs = {}
      terraform_dir = File.join(@dir, "terraform/#{@stage}")

      unless File.exists?(@config_path)
        puts "Config file #{@config_path} does not exist, creating..."
        
        example = <<~END
          aws_profile: your AWS CLI profile
          
          app: #{File.basename(@dir)}
          env: #{@stage}

          cluster: #{@stage}
          repository: your ECR repository
          subnets:
            - subnet 1
            - subnet 2

          roles:
            task: ECS task role ARN
            execution: ECS execution role ARN

          tasks:
            example:
              security_groups:
                - sg1
                - sg2
              ports:
                - 500
              awslogs:
                region: us-east-1
                group: /ecs/#{File.basename(@dir)}/#{@stage}
        END

        FileUtils.mkdir_p(File.dirname(@config_path))
        File.write(@config_path, example)
      end
      
      if File.exists?(terraform_dir)
        outputs = read_terraform_outputs(terraform_dir)
      else
        warn "No terraform found at #{terraform_dir}"
      end

      ECSUtil::Config.read(@config_path, @stage, outputs)
    end
  end
end