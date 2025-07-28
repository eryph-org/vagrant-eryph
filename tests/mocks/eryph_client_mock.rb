require 'json'

class EryphClientMock
  attr_reader :catlets, :projects, :last_operation
  
  def initialize
    @catlets = {}
    @projects = {}
    @last_operation = nil
    @operation_delay = 0.1  # Simulate async operations
  end
  
  # Project management
  def list_projects
    @last_operation = :list_projects
    @projects.values
  end
  
  def get_project(name)
    @last_operation = :get_project
    @projects[name]
  end
  
  def create_project(project_config)
    @last_operation = :create_project
    project = {
      id: generate_id,
      name: project_config[:name],
      description: project_config[:description] || "",
      created_at: Time.now.iso8601
    }
    @projects[project[:name]] = project
    project
  end
  
  def delete_project(name)
    @last_operation = :delete_project
    @projects.delete(name)
  end
  
  # Catlet management
  def list_catlets(project_name = nil)
    @last_operation = :list_catlets
    if project_name
      @catlets.values.select { |c| c[:project] == project_name }
    else
      @catlets.values
    end
  end
  
  def get_catlet(id)
    @last_operation = :get_catlet
    catlet = @catlets[id]
    return nil unless catlet
    
    # Simulate catlet with full details
    catlet.merge(
      networks: catlet[:networks] || [],
      drives: catlet[:drives] || [],
      metadata: catlet[:metadata] || {}
    )
  end
  
  def create_catlet(catlet_config)
    @last_operation = :create_catlet
    
    id = generate_id
    catlet = {
      id: id,
      name: catlet_config[:name],
      project: catlet_config[:project],
      parent_gene: catlet_config[:parent_gene],
      cpu: catlet_config[:cpu] || 1,
      memory: catlet_config[:memory] || 1024,
      state: :stopped,
      ip_addresses: [],
      networks: catlet_config[:networks] || [],
      drives: catlet_config[:drives] || [],
      fodder: catlet_config[:fodder] || [],
      created_at: Time.now.iso8601,
      updated_at: Time.now.iso8601
    }
    
    @catlets[id] = catlet
    
    # Simulate async operation
    Thread.new do
      sleep @operation_delay
      catlet[:state] = :running
      catlet[:ip_addresses] = generate_ip_addresses
      catlet[:updated_at] = Time.now.iso8601
    end
    
    { operation_id: generate_id, catlet_id: id }
  end
  
  def start_catlet(id)
    @last_operation = :start_catlet
    catlet = @catlets[id]
    return nil unless catlet
    
    operation_id = generate_id
    
    Thread.new do
      sleep @operation_delay
      catlet[:state] = :running
      catlet[:ip_addresses] = generate_ip_addresses unless catlet[:ip_addresses].any?
      catlet[:updated_at] = Time.now.iso8601
    end
    
    { operation_id: operation_id }
  end
  
  def stop_catlet(id)
    @last_operation = :stop_catlet
    catlet = @catlets[id]
    return nil unless catlet
    
    operation_id = generate_id
    
    Thread.new do
      sleep @operation_delay
      catlet[:state] = :stopped
      catlet[:updated_at] = Time.now.iso8601
    end
    
    { operation_id: operation_id }
  end
  
  def delete_catlet(id)
    @last_operation = :delete_catlet
    catlet = @catlets[id]
    return nil unless catlet
    
    operation_id = generate_id
    
    Thread.new do
      sleep @operation_delay
      @catlets.delete(id)
    end
    
    { operation_id: operation_id }
  end
  
  # Operation monitoring
  def get_operation(operation_id)
    @last_operation = :get_operation
    
    # Simulate operation completion
    {
      id: operation_id,
      status: :completed,
      progress: 100,
      created_at: Time.now.iso8601,
      completed_at: Time.now.iso8601
    }
  end
  
  def wait_for_operation(operation_id, timeout = 300)
    @last_operation = :wait_for_operation
    
    # Simulate waiting
    sleep @operation_delay
    
    get_operation(operation_id)
  end
  
  # Configuration and status
  def get_identity
    @last_operation = :get_identity
    {
      endpoint: "http://localhost:8080",
      identity: "test-user",
      authenticated: true
    }
  end
  
  def list_genes
    @last_operation = :list_genes
    [
      {
        name: "dbosoft/ubuntu-22.04/latest",
        os: "linux",
        version: "latest"
      },
      {
        name: "dbosoft/winsrv2022-standard/latest",
        os: "windows",
        version: "latest"
      }
    ]
  end
  
  # Helper methods for testing
  def set_operation_delay(seconds)
    @operation_delay = seconds
  end
  
  def simulate_catlet_running(id)
    catlet = @catlets[id]
    return unless catlet
    
    catlet[:state] = :running
    catlet[:ip_addresses] = generate_ip_addresses
  end
  
  def simulate_error(error_type)
    case error_type
    when :network_error
      raise StandardError, "Network connection failed"
    when :auth_error
      raise StandardError, "Authentication failed"
    when :not_found
      raise StandardError, "Resource not found"
    else
      raise StandardError, "Simulated error: #{error_type}"
    end
  end
  
  def reset
    @catlets.clear
    @projects.clear
    @last_operation = nil
  end
  
  private
  
  def generate_id
    "test-#{Time.now.to_f}-#{rand(1000)}"
  end
  
  def generate_ip_addresses
    [
      "192.168.1.#{rand(50) + 100}",
      "10.0.0.#{rand(50) + 100}"
    ]
  end
end