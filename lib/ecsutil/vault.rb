module ECSUtil
  module Vault
    def vault_call(command, args, opts = {})
      args += " --vault-id=#{opts[:vault_id]}"
      cmd = "ansible-vault #{command} #{args}"
      
      return exec(cmd) if opts[:shellout]
        
      output = `#{cmd}`
      unless $?.success?
        fail "Ansible error"
      end

      output.strip
    end
  end
end