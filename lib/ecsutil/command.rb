require "ecsutil/helpers"
require "ecsutil/aws"
require "ecsutil/vault"
require "ecsutil/shared"

module ECSUtil
  module Commands
  end

  class Command
    include ECSUtil::Helpers
    include ECSUtil::AWS
    include ECSUtil::Vault
    include ECSUtil::Shared

    attr_reader :config, :action, :args

    def initialize(config, action = nil, args = [])
      @config = config
      @action = action
      @args   = args
    end
  end
end