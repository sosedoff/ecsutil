require "yaml"
require "hashie"

module ECSUtil
  class Config < Hashie::Mash
    # Do not show any Hashie warnings
    disable_warnings

    def self.read(path, stage, outputs = {})
      data = File.read(path).gsub(/(\$tf.([\w]+))+/i) do |m|
        key = $2
        fail "Terraform output key #{key} not found!" unless outputs[key]
        outputs[key]
      end

      result = YAML.load(data).tap do |config|
        fail "App name is required"   unless config["app"]
        fail "App env is required"    unless config["env"]
        fail "Cluster is required"    unless config["cluster"]
        fail "Repository is required" unless config["repository"]
        
        # Check AWS configuration
        if !config["aws_profile"] && !ENV["AWS_PROFILE"]
          fail "AWS profile is not set! Set 'aws_profile' var in config or use AWS_PROFILE env var!"
        end

        # Override environment variable in case if it was set
        ENV["AWS_PROFILE"] = config["aws_profile"]

        # Set stage and namespace
        config["user"] ||= `whoami`.strip
        config["stage"] ||= stage
        config["namespace"] ||= sprintf("%s-%s", config["app"], config["env"])

        # Set default sections
        config["tasks"] ||= {}
        config["scheduled_tasks"] ||= {}
        config["services"] ||= {}

        # Parent dir
        parent_dir = File.expand_path(File.join(File.dirname(path), ".."))

        # Set secrets
        config.merge!(
          "secrets_vaultpass" => File.join(parent_dir, "vaultpass"),
          "secrets_file"      => File.join(File.dirname(path), "#{stage}/secrets"),
          "secrets_key"       => outputs["kms_key"],
          "secrets_prefix"    => sprintf("/%s", config["namespace"]),
          "secrets_data"      => {}
        )

        # Set default vars
        config["git_commit"] ||= `git rev-parse HEAD`.strip
        config["git_branch"] ||= `git rev-parse --abbrev-ref HEAD`.strip
      end

      Config.new(result)
    end
  end
end