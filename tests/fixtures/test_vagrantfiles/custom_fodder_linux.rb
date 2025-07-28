# Linux catlet with custom cloud-init fodder
Vagrant.configure("2") do |config|
  config.vm.provider :eryph do |eryph|
    eryph.project = "test-custom-fodder"
    eryph.parent_gene = "dbosoft/ubuntu-22.04/latest"
    eryph.auto_config = true
    
    # Custom cloud-init configuration
    eryph.fodder = [
      {
        name: "development-packages",
        type: "cloud-config",
        content: {
          "packages" => [
            "git", "curl", "wget", "vim", "htop", "tree",
            "build-essential", "nodejs", "npm", "python3-pip"
          ],
          "runcmd" => [
            "echo 'Development environment setup completed' >> /var/log/dev-setup.log",
            "pip3 install --upgrade pip",
            "npm install -g yarn",
            "mkdir -p /home/vagrant/projects",
            "chown vagrant:vagrant /home/vagrant/projects"
          ]
        }
      },
      {
        name: "docker-installation",
        type: "cloud-config",
        content: {
          "runcmd" => [
            "curl -fsSL https://get.docker.com -o get-docker.sh",
            "sh get-docker.sh",
            "usermod -aG docker vagrant",
            "systemctl enable docker",
            "systemctl start docker"
          ]
        }
      },
      {
        name: "custom-bashrc",
        type: "cloud-config",
        content: {
          "write_files" => [
            {
              "path" => "/home/vagrant/.bashrc_custom",
              "content" => <<~BASH
                # Custom bash configuration for development
                export EDITOR=vim
                export HISTSIZE=10000
                export HISTFILESIZE=20000
                
                alias ll='ls -alF'
                alias la='ls -A'
                alias l='ls -CF'
                alias ..='cd ..'
                alias ...='cd ../..'
                
                # Git aliases
                alias gs='git status'
                alias ga='git add'
                alias gc='git commit'
                alias gp='git push'
                alias gl='git log --oneline'
                
                echo "Custom development environment loaded"
              BASH
              ,
              "owner" => "vagrant:vagrant",
              "permissions" => "0644"
            }
          ],
          "runcmd" => [
            "echo 'source ~/.bashrc_custom' >> /home/vagrant/.bashrc"
          ]
        }
      }
    ]
  end
  
  config.vm.hostname = "dev-environment"
  
  # Test provisioning that validates our custom setup
  config.vm.provision "shell", inline: <<-SHELL
    echo "=== Validating Development Environment Setup ==="
    
    # Check packages
    echo "Checking installed packages..."
    dpkg -l | grep -E "(git|curl|vim|nodejs|python3-pip)" | wc -l
    
    # Check Docker
    echo "Checking Docker installation..."
    docker --version
    
    # Check custom bashrc
    echo "" 
    echo "Checking custom bashrc..."
    if [ -f /home/vagrant/.bashrc_custom ]; then
      echo "Custom bashrc found"
    else
      echo "Custom bashrc missing"
    fi
    
    # Check development directory
    echo "Checking projects directory..."
    ls -la /home/vagrant/projects
    
    echo "=== Development Environment Validation Complete ==="
  SHELL
end