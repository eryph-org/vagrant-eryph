require_relative '../support/test_helper'
require_relative '../mocks/eryph_client_mock'

class FullLifecycleTest
  include TestHelper
  
  def run_all
    puts "🔄 Testing full catlet lifecycle with mock client..."
    
    tests = [
      :test_mock_client_setup,
      :test_project_management,
      :test_linux_catlet_lifecycle,
      :test_windows_catlet_lifecycle,
      :test_error_handling,
      :test_concurrent_operations,
      :test_resource_management
    ]
    
    results = tests.map { |test| run_test_method(test.to_s.gsub('test_', ''), method(test)) }
    
    if results.all?
      puts "✅ All end-to-end tests passed!"
    else
      puts "❌ Some end-to-end tests failed"
      false
    end
  end
  
  private
  
  def setup_mock_client
    @mock_client = EryphClientMock.new
    # Simulate environment variable for mock mode
    ENV['VAGRANT_ERYPH_MOCK_CLIENT'] = 'true'
    @mock_client
  end
  
  def cleanup_mock_client
    ENV.delete('VAGRANT_ERYPH_MOCK_CLIENT')
    @mock_client = nil
  end
  
  def test_mock_client_setup
    client = setup_mock_client
    
    # Test basic client functionality
    identity = client.get_identity
    assert_not_nil(identity, "Should get identity information")
    assert_equal("test-user", identity[:identity], "Should return test user")
    assert_equal(true, identity[:authenticated], "Should be authenticated")
    
    # Test gene listing
    genes = client.list_genes
    assert(genes.length >= 2, "Should list test genes")
    assert(genes.any? { |g| g[:name] == "dbosoft/ubuntu-22.04/latest" }, "Should include Ubuntu gene")
    assert(genes.any? { |g| g[:name] == "dbosoft/winsrv2022-standard/latest" }, "Should include Windows gene")
    
    cleanup_mock_client
    true
  end
  
  def test_project_management
    client = setup_mock_client
    
    project_name = "test-lifecycle-project"
    
    # Test project creation
    project = client.create_project(name: project_name, description: "Test project for lifecycle")
    assert_not_nil(project, "Should create project")
    assert_equal(project_name, project[:name], "Should set correct project name")
    
    # Test project listing
    projects = client.list_projects
    assert(projects.any? { |p| p[:name] == project_name }, "Should list created project")
    
    # Test project retrieval
    retrieved_project = client.get_project(project_name)
    assert_not_nil(retrieved_project, "Should retrieve project")
    assert_equal(project[:id], retrieved_project[:id], "Should retrieve correct project")
    
    # Test project deletion
    client.delete_project(project_name)
    deleted_project = client.get_project(project_name)
    assert_nil(deleted_project, "Should delete project")
    
    cleanup_mock_client
    true
  end
  
  def test_linux_catlet_lifecycle
    client = setup_mock_client
    
    # Create project first
    project = client.create_project(name: "linux-test", description: "Linux catlet test")
    
    # Test catlet creation
    catlet_config = {
      name: "test-ubuntu",
      project: "linux-test",
      parent_gene: "dbosoft/ubuntu-22.04/latest",
      cpu: 2,
      memory: 2048,
      fodder: [
        {
          name: "test-fodder",
          type: "cloud-config",
          content: { "packages" => ["git", "curl"] }
        }
      ]
    }
    
    create_result = client.create_catlet(catlet_config)
    assert_not_nil(create_result[:catlet_id], "Should create catlet")
    assert_not_nil(create_result[:operation_id], "Should return operation ID")
    
    catlet_id = create_result[:catlet_id]
    
    # Wait for creation to complete
    operation = client.wait_for_operation(create_result[:operation_id])
    assert_equal(:completed, operation[:status], "Creation should complete")
    
    # Test catlet retrieval
    catlet = client.get_catlet(catlet_id)
    assert_not_nil(catlet, "Should retrieve catlet")
    assert_equal("test-ubuntu", catlet[:name], "Should have correct name")
    assert_equal("linux-test", catlet[:project], "Should be in correct project")
    assert_equal(2, catlet[:cpu], "Should have correct CPU count")
    assert_equal(2048, catlet[:memory], "Should have correct memory")
    
    # Simulate catlet startup
    client.simulate_catlet_running(catlet_id)
    updated_catlet = client.get_catlet(catlet_id)
    assert_equal(:running, updated_catlet[:state], "Should be running")
    assert(updated_catlet[:ip_addresses].any?, "Should have IP addresses")
    
    # Test catlet stop
    stop_result = client.stop_catlet(catlet_id)
    assert_not_nil(stop_result[:operation_id], "Should return stop operation ID")
    
    # Wait for stop to complete
    client.wait_for_operation(stop_result[:operation_id])
    stopped_catlet = client.get_catlet(catlet_id)
    assert_equal(:stopped, stopped_catlet[:state], "Should be stopped")
    
    # Test catlet restart
    start_result = client.start_catlet(catlet_id)
    assert_not_nil(start_result[:operation_id], "Should return start operation ID")
    
    # Test catlet deletion
    delete_result = client.delete_catlet(catlet_id)
    assert_not_nil(delete_result[:operation_id], "Should return delete operation ID")
    
    # Wait for deletion
    client.wait_for_operation(delete_result[:operation_id])
    deleted_catlet = client.get_catlet(catlet_id)
    assert_nil(deleted_catlet, "Should delete catlet")
    
    cleanup_mock_client
    true
  end
  
  def test_windows_catlet_lifecycle
    client = setup_mock_client
    
    # Create project
    project = client.create_project(name: "windows-test", description: "Windows catlet test")
    
    # Test Windows catlet creation
    catlet_config = {
      name: "test-windows",
      project: "windows-test", 
      parent_gene: "dbosoft/winsrv2022-standard/latest",
      cpu: 4,
      memory: 4096,
      fodder: [
        {
          name: "windows-setup",
          type: "shellscript",
          content: "#ps1_sysnative\nWrite-Host 'Windows setup completed'"
        }
      ]
    }
    
    create_result = client.create_catlet(catlet_config)
    catlet_id = create_result[:catlet_id]
    
    # Wait for creation
    client.wait_for_operation(create_result[:operation_id])
    
    # Test Windows catlet properties
    catlet = client.get_catlet(catlet_id)
    assert_equal("test-windows", catlet[:name], "Should have correct name")
    assert_equal(4, catlet[:cpu], "Should have correct CPU count for Windows")
    assert_equal(4096, catlet[:memory], "Should have correct memory for Windows")
    assert(catlet[:fodder].any? { |f| f[:type] == "shellscript" }, "Should have PowerShell fodder")
    
    # Test lifecycle operations
    client.simulate_catlet_running(catlet_id)
    stop_result = client.stop_catlet(catlet_id)
    client.wait_for_operation(stop_result[:operation_id])
    
    start_result = client.start_catlet(catlet_id)
    client.wait_for_operation(start_result[:operation_id])
    
    delete_result = client.delete_catlet(catlet_id)
    client.wait_for_operation(delete_result[:operation_id])
    
    deleted_catlet = client.get_catlet(catlet_id)
    assert_nil(deleted_catlet, "Should delete Windows catlet")
    
    cleanup_mock_client
    true
  end
  
  def test_error_handling
    client = setup_mock_client
    
    # Test operations on non-existent catlet
    result = client.get_catlet("non-existent-id")
    assert_nil(result, "Should return nil for non-existent catlet")
    
    result = client.start_catlet("non-existent-id")  
    assert_nil(result, "Should return nil when starting non-existent catlet")
    
    result = client.stop_catlet("non-existent-id")
    assert_nil(result, "Should return nil when stopping non-existent catlet")
    
    result = client.delete_catlet("non-existent-id")
    assert_nil(result, "Should return nil when deleting non-existent catlet")
    
    # Test error simulation
    begin
      client.simulate_error(:network_error)
      assert(false, "Should raise network error")
    rescue => e
      assert(e.message.include?("Network connection failed"), "Should raise network error")
    end
    
    begin
      client.simulate_error(:auth_error)
      assert(false, "Should raise auth error")
    rescue => e
      assert(e.message.include?("Authentication failed"), "Should raise auth error")
    end
    
    cleanup_mock_client
    true
  end
  
  def test_concurrent_operations
    client = setup_mock_client
    
    # Create project
    project = client.create_project(name: "concurrent-test", description: "Concurrent operations test")
    
    # Create multiple catlets concurrently
    catlet_configs = [
      { name: "concurrent-1", project: "concurrent-test", parent_gene: "dbosoft/ubuntu-22.04/latest", cpu: 1, memory: 1024 },
      { name: "concurrent-2", project: "concurrent-test", parent_gene: "dbosoft/ubuntu-22.04/latest", cpu: 1, memory: 1024 },
      { name: "concurrent-3", project: "concurrent-test", parent_gene: "dbosoft/ubuntu-22.04/latest", cpu: 1, memory: 1024 }
    ]
    
    create_results = []
    catlet_configs.each do |config|
      result = client.create_catlet(config)
      create_results << result
    end
    
    # Wait for all creations to complete
    create_results.each do |result|
      operation = client.wait_for_operation(result[:operation_id])
      assert_equal(:completed, operation[:status], "All concurrent creations should complete")
    end
    
    # Verify all catlets were created
    catlets = client.list_catlets("concurrent-test")
    assert_equal(3, catlets.length, "Should create all concurrent catlets")
    
    # Test concurrent operations on existing catlets
    catlet_ids = create_results.map { |r| r[:catlet_id] }
    
    # Start all catlets concurrently
    start_results = []
    catlet_ids.each do |id|
      client.simulate_catlet_running(id)
      result = client.start_catlet(id)
      start_results << result if result
    end
    
    # Clean up
    catlet_ids.each do |id|
      delete_result = client.delete_catlet(id)
      client.wait_for_operation(delete_result[:operation_id]) if delete_result
    end
    
    cleanup_mock_client
    true
  end
  
  def test_resource_management
    client = setup_mock_client
    
    # Create project
    project = client.create_project(name: "resource-test", description: "Resource management test")
    
    # Test high-resource catlet
    high_resource_config = {
      name: "high-resource",
      project: "resource-test",
      parent_gene: "dbosoft/ubuntu-22.04/latest",
      cpu: 8,
      memory: 16384,
      drives: [
        { name: "data-drive", size: 100 },
        { name: "backup-drive", size: 50 }
      ],
      networks: [
        { name: "high-perf-network", adapter_name: "eth1" }
      ]
    }
    
    create_result = client.create_catlet(high_resource_config)
    catlet_id = create_result[:catlet_id]
    
    # Wait for creation
    client.wait_for_operation(create_result[:operation_id])
    
    # Verify resource allocation
    catlet = client.get_catlet(catlet_id)
    assert_equal(8, catlet[:cpu], "Should allocate requested CPU")
    assert_equal(16384, catlet[:memory], "Should allocate requested memory")
    assert_equal(2, catlet[:drives].length, "Should attach requested drives")
    assert_equal(1, catlet[:networks].length, "Should configure requested networks")
    
    # Test resource limits and validation would go here in a real implementation
    
    # Clean up
    delete_result = client.delete_catlet(catlet_id)
    client.wait_for_operation(delete_result[:operation_id])
    
    cleanup_mock_client
    true
  end
end