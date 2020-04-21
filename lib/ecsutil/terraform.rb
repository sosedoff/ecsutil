require "json"

module ECSUtil
  module Terraform
    def read_terraform_outputs(dir)
      outputs = {}

      Dir.chdir(dir) do
        result = `terraform output -json`.strip
        unless $?.success?
          fail "Terraform error: #{result}"
        end
    
        JSON.load(result).each_pair do |key, data|
          outputs[key] = data["value"]
        end
      end

      outputs
    end
  end
end
