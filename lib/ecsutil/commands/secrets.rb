class ECSUtil::Commands::SecretsCommand < ECSUtil::Command
  def run
    case action
    when nil, "show"
      show_local_secrets
    when "edit"
      edit_secrets
    when "push"
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
    vault_read(config["secrets_file"], config["secrets_vaultpass"])
  end

  def show_local_secrets
    step_info "Loading secrets from %s", config["secrets_file"]
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
    step_info "Editing secrets file %s", config["secrets_file"]
    vault_edit(config["secrets_file"], config["secrets_vaultpass"])
  end

  def push_secrets
    confirm("Will push secrets live to #{config["secrets_prefix"]}")
    load_secrets

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
