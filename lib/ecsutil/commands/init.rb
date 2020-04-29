require "securerandom"

class ECSUtil::Commands::InitCommand < ECSUtil::Command
  def run
    init_password_file
    check_password_contents
    check_gitignore
    init_terraform
  end

  private

  def password_path
    @password_path ||= config.secrets_vaultpass
  end

  def gitignore_path
    @gitignore_path ||= File.join(Dir.pwd, ".gitignore")
  end

  def terraform_path
    @terraform_path ||= File.join(Dir.pwd, "terraform", config.stage)
  end

  def init_password_file
    if !password_path || password_path && !File.exists?(password_path)
      create_password_file
    end
  end

  def create_password_file
    step_info "Vault password file not found at #{password_path}, creating..."
    File.write(password_path, SecureRandom.hex(20))
  end

  def check_password_contents
    if File.read(password_path).strip.empty?
      terminate "Your vault password file is empty!"
    end
  end

  def check_gitignore
    unless File.exists?(gitignore_path)
      step_info "Creating .gitignore file"
      FileUtils.touch(gitignore_path)
    end

    data = File.read(gitignore_path)
    return if data.include?("vaultpass")
    
    step_info "Adding vaultpass to .gitignore"
    data += "\nvaultpass"
    File.write(gitignore_path, data.strip + "\n")
  end

  def init_terraform
    step_info "Checking if Terraform is installed"
    if `which terraform`.strip.empty?
      step_info "Terraform is not found, skipping..."
      return
    end

    unless File.exists?(terraform_path)
      step_info "Setting up Terraform directory at #{terraform_path}"
      FileUtils.mkdir_p(terraform_path)
    end
  end
end