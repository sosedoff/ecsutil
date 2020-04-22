class ECSUtil::Commands::SecretsCommand < ECSUtil::Command
  def run
    case action
    when nil, "show"
      step_info "Loading local secrets"
      show_local_secrets
    when "edit"
      edit_secrets
    when "push"
      confirm("Will push secrets live to #{config["secrets_prefix"]}")
      load_secrets
      push_secrets
    when "live"
      load_secrets
      show_live_secrets
    when "delete"
      confirm
      load_secrets
      deregister_secrets
    else
      fail "Invalid action: #{action}"
    end
  end

  private

  def load_local_secrets
    vault_call("view", config["secrets_file"], vault_id: config["secrets_vaultpass"])
  end

  def show_local_secrets
    puts load_local_secrets
  end

  def show_live_secrets
    if config["secrets_data"].empty?
      puts "No secrets found for prefix #{config["secrets_prefix"]}"
      return
    end
    
    config["secrets_data"].each do |secret|
      printf("%s=%s\n", secret[:key], secret[:value])
    end
  end

  def edit_secrets
    vault_call("edit", config["secrets_file"], {
      vault_id: config["secrets_vaultpass"],
      shellout: true
    })
  end

  def push_secrets
    local = parse_env_data(load_local_secrets)
    live  = config["secrets_data"].map { |item| [item[:key], item[:value]] }.to_h

    added_count   = 0
    skipped_count = 0
    removed_count = 0

    local.each_pair do |key, value|
      if live[key] == value
        step_info "Skipping #{key}, already set"
        skipped_count += 1
        next
      end

      step_info "Setting #{key} to #{value}"
      aws_call("ssm", "put-parameter", {
        Type:      "SecureString",
        Name:      sprintf("%s/%s", config["secrets_prefix"], key),
        Value:     value,
        KeyId:     config["secrets_key"],
        Overwrite: true
      })
      added_count += 1
    end

    config["secrets_data"].each do |secret|
      if !local[secret[:key]]
        step_info "Removing #{secret[:key]}"
        aws_call("ssm", "delete-parameter", "--name=#{secret[:name]}")
        removed_count += 1
      end
    end

    step_info "Skipped: %d, Added: %d, Removed: %d\n",
      skipped_count,
      added_count,
      removed_count
  end
end