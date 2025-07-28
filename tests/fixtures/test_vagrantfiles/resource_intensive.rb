# Resource-intensive configuration for testing scaling
Vagrant.configure("2") do |config|
  config.vm.provider :eryph do |eryph|
    eryph.project = "test-resource-intensive"
    eryph.parent_gene = "dbosoft/ubuntu-22.04/latest"
    eryph.auto_config = true
    
    # High resource configuration
    eryph.cpu = 8
    eryph.memory = 16384  # 16GB RAM
    
    # Custom drives configuration
    eryph.drives = [
      {
        name: "data-drive",
        size: 100  # 100GB data drive
      },
      {
        name: "backup-drive", 
        size: 50   # 50GB backup drive
      }
    ]
    
    # Custom network configuration
    eryph.networks = [
      {
        name: "high-performance-network",
        adapter_name: "eth1"
      },
      {
        name: "storage-network",
        adapter_name: "eth2"
      }
    ]
    
    # Performance-oriented cloud-init setup
    eryph.fodder = [
      {
        name: "performance-tuning",
        type: "cloud-config",
        content: {
          "packages" => [
            "htop", "iotop", "sysstat", "stress-ng", "fio",
            "build-essential", "cmake", "git", "wget", "curl"
          ],
          "runcmd" => [
            # CPU performance settings
            "echo 'performance' > /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor",
            
            # Memory settings
            "echo 'vm.swappiness=10' >> /etc/sysctl.conf",
            "echo 'vm.vfs_cache_pressure=50' >> /etc/sysctl.conf",
            "echo 'vm.dirty_ratio=15' >> /etc/sysctl.conf",
            "echo 'vm.dirty_background_ratio=5' >> /etc/sysctl.conf",
            
            # Network performance
            "echo 'net.core.rmem_max = 67108864' >> /etc/sysctl.conf",
            "echo 'net.core.wmem_max = 67108864' >> /etc/sysctl.conf",
            "echo 'net.ipv4.tcp_rmem = 4096 87380 67108864' >> /etc/sysctl.conf",
            "echo 'net.ipv4.tcp_wmem = 4096 65536 67108864' >> /etc/sysctl.conf",
            
            # Apply settings
            "sysctl -p",
            
            # Set up monitoring
            "systemctl enable sysstat",
            "systemctl start sysstat",
            
            # Create performance test scripts
            "mkdir -p /home/vagrant/performance-tests",
            "chown vagrant:vagrant /home/vagrant/performance-tests"
          ]
        }
      },
      {
        name: "drive-setup",
        type: "cloud-config",
        content: {
          "runcmd" => [
            # Format and mount additional drives (assuming they appear as /dev/sdb and /dev/sdc)
            "if [ -b /dev/sdb ]; then mkfs.ext4 /dev/sdb && mkdir -p /mnt/data && mount /dev/sdb /mnt/data && echo '/dev/sdb /mnt/data ext4 defaults 0 2' >> /etc/fstab; fi",
            "if [ -b /dev/sdc ]; then mkfs.ext4 /dev/sdc && mkdir -p /mnt/backup && mount /dev/sdc /mnt/backup && echo '/dev/sdc /mnt/backup ext4 defaults 0 2' >> /etc/fstab; fi",
            
            # Set permissions
            "if [ -d /mnt/data ]; then chown vagrant:vagrant /mnt/data; fi",
            "if [ -d /mnt/backup ]; then chown vagrant:vagrant /mnt/backup; fi",
            
            # Create test data
            "if [ -d /mnt/data ]; then echo 'High-performance data drive ready' > /mnt/data/README.txt; fi",
            "if [ -d /mnt/backup ]; then echo 'Backup drive ready' > /mnt/backup/README.txt; fi"
          ]
        }
      },
      {
        name: "benchmark-tools",
        type: "cloud-config",
        content: {
          "write_files" => [
            {
              "path" => "/home/vagrant/performance-tests/cpu-test.sh",
              "content" => <<~SCRIPT
                #!/bin/bash
                echo "=== CPU Performance Test ==="
                echo "CPU cores: $(nproc)"
                echo "CPU info:"
                lscpu | grep "Model name"
                lscpu | grep "CPU MHz"
                echo ""
                echo "Running CPU stress test for 30 seconds..."
                stress-ng --cpu $(nproc) --timeout 30s --metrics-brief
              SCRIPT
              ,
              "owner" => "vagrant:vagrant",
              "permissions" => "0755"
            },
            {
              "path" => "/home/vagrant/performance-tests/memory-test.sh", 
              "content" => <<~SCRIPT
                #!/bin/bash
                echo "=== Memory Performance Test ==="
                echo "Total memory: $(free -h | grep Mem | awk '{print $2}')"
                echo "Available memory: $(free -h | grep Mem | awk '{print $7}')"
                echo ""
                echo "Running memory stress test for 30 seconds..."
                stress-ng --vm 2 --vm-bytes 75% --timeout 30s --metrics-brief
              SCRIPT
              ,
              "owner" => "vagrant:vagrant",
              "permissions" => "0755"
            },
            {
              "path" => "/home/vagrant/performance-tests/disk-test.sh",
              "content" => <<~SCRIPT
                #!/bin/bash
                echo "=== Disk Performance Test ==="
                echo "Disk usage:"
                df -h
                echo ""
                echo "Running disk I/O test..."
                if [ -d /mnt/data ]; then
                  echo "Testing data drive performance..."
                  fio --name=random-write --ioengine=posixaio --rw=randwrite --bs=4k --numjobs=1 --size=100m --runtime=30 --time_based --end_fsync=1 --filename=/mnt/data/testfile --directory=/mnt/data
                  rm -f /mnt/data/testfile
                else
                  echo "Testing root drive performance..."
                  fio --name=random-write --ioengine=posixaio --rw=randwrite --bs=4k --numjobs=1 --size=100m --runtime=30 --time_based --end_fsync=1 --filename=/tmp/testfile
                  rm -f /tmp/testfile
                fi
              SCRIPT
              ,
              "owner" => "vagrant:vagrant",
              "permissions" => "0755"
            },
            {
              "path" => "/home/vagrant/performance-tests/network-test.sh",
              "content" => <<~SCRIPT
                #!/bin/bash
                echo "=== Network Performance Test ==="
                echo "Network interfaces:"
                ip addr show | grep "inet " | grep -v "127.0.0.1"
                echo ""
                echo "Network configuration:"
                ip route show
                echo ""
                echo "Network performance settings:"
                sysctl net.core.rmem_max net.core.wmem_max
              SCRIPT
              ,
              "owner" => "vagrant:vagrant", 
              "permissions" => "0755"
            },
            {
              "path" => "/home/vagrant/performance-tests/run-all-tests.sh",
              "content" => <<~SCRIPT
                #!/bin/bash
                echo "=========================================="
                echo "    ERYPH HIGH-PERFORMANCE CATLET TEST    "
                echo "=========================================="
                echo ""
                
                ./cpu-test.sh
                echo ""
                ./memory-test.sh
                echo ""
                ./disk-test.sh
                echo ""
                ./network-test.sh
                echo ""
                
                echo "=========================================="
                echo "         PERFORMANCE TESTS COMPLETED     "
                echo "=========================================="
              SCRIPT
              ,
              "owner" => "vagrant:vagrant",
              "permissions" => "0755"
            }
          ]
        }
      }
    ]
  end
  
  config.vm.hostname = "high-performance"
  
  # Validation provisioning
  config.vm.provision "shell", inline: <<-SHELL
    echo "=== High-Performance Catlet Validation ==="
    
    # System resources
    echo "CPU cores: $(nproc)"
    echo "Total memory: $(free -h | grep Mem | awk '{print $2}')"
    echo "Disk space:"
    df -h | grep -E "(/$|/mnt)"
    
    # Performance settings
    echo ""
    echo "Performance governor:"
    cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
    
    echo ""
    echo "Memory settings:"
    grep -E "(swappiness|vfs_cache_pressure|dirty_ratio)" /etc/sysctl.conf
    
    echo ""
    echo "Network interfaces:"
    ip addr show | grep "^[0-9]" | awk '{print $2}'
    
    echo ""
    echo "Available performance tests:"
    ls -la /home/vagrant/performance-tests/
    
    echo ""
    echo "To run performance benchmarks, use:"
    echo "  vagrant ssh -c 'cd performance-tests && ./run-all-tests.sh'"
  SHELL
end