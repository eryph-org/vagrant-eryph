# Basic Linux catlet configuration for testing
Vagrant.configure("2") do |config|
  config.vm.provider :eryph do |eryph|
    eryph.project = "test-basic-linux"
    eryph.parent_gene = "dbosoft/ubuntu-22.04/latest"
    eryph.auto_config = true
    eryph.cpu = 2
    eryph.memory = 2048
  end
  
  config.vm.hostname = "basic-linux-test"
  
  config.vm.provision "shell", inline: <<-SHELL
    echo "Basic Linux catlet provisioning test"
    echo "Hostname: $(hostname)"
    echo "User: $(whoami)"
    echo "OS: $(lsb_release -d)"
  SHELL
end