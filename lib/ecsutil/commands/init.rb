require "securerandom"

class ECSUtil::Commands::InitCommand < ECSUtil::Command
  def run
    init_password_file
    check_password_contents
    check_gitignore
  end

  private

  def password_path
    @password_path ||= config.secrets_vaultpass
  end

  def gitignore_path
    @gitignore_path ||= File.join(Dir.pwd, ".gitignore")
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
end