require "tempfile"
require "ansible/vault"

module ECSUtil
  module Vault
    def vault_read(path, password_path)
      Ansible::Vault.read(
        path: path,
        password: File.read(password_path)
      )
    end

    def vault_write(path, password_path, data)
      Ansible::Vault.write(
        path: path,
        password: File.read(password_path),
        plaintext: data
      )
    end

    def vault_edit(path, password_path)
      temp = Tempfile.new
      temp.write(vault_read(path, password_path))
      temp.flush

      editor_path = `which $EDITOR`.strip
      if editor_path.empty?
        fail "EDITOR is not set!"
      end

      system "#{editor_path} #{temp.path}"
      unless $?.success?
        fail "Unable to save temp file"
      end

      vault_write(path, password_path, File.read(temp.path))

      temp.close
      temp.unlink
    end
  end
end