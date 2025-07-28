require_relative 'support/test_helper'

class StructureTest
  include TestHelper
  
  def run_all
    puts "📂 Validating plugin file structure..."
    
    tests = [
      :test_core_files_exist,
      :test_helper_files_exist,
      :test_action_files_exist,
      :test_example_files_exist,
      :test_configuration_content,
      :test_cloud_init_content,
      :test_gemspec_validity,
      :test_plugin_registration,
      :test_localization_files
    ]
    
    results = tests.map { |test| run_test_method(test.to_s.gsub('test_', ''), method(test)) }
    
    if results.all?
      puts "✅ All structure tests passed!"
    else
      puts "❌ Some structure tests failed"
      false
    end
  end
  
  private
  
  def project_root
    File.expand_path('..', __dir__)
  end
  
  def project_file(path)
    File.join(project_root, path)
  end
  
  def test_core_files_exist
    core_files = [
      'lib/vagrant-eryph.rb',
      'lib/vagrant-eryph/plugin.rb',
      'lib/vagrant-eryph/provider.rb',
      'lib/vagrant-eryph/config.rb',
      'lib/vagrant-eryph/version.rb',
      'lib/vagrant-eryph/actions.rb',
      'lib/vagrant-eryph/errors.rb',
      'lib/vagrant-eryph/command.rb',
      'vagrant-eryph.gemspec'
    ]
    
    core_files.each { |file| assert_file_exists(project_file(file), "Core file missing: #{file}") }
    true
  end
  
  def test_helper_files_exist
    helper_files = [
      'lib/vagrant-eryph/helpers/cloud_init.rb',
      'lib/vagrant-eryph/helpers/ssh_key.rb',
      'lib/vagrant-eryph/helpers/eryph_client.rb'
    ]
    
    helper_files.each { |file| assert_file_exists(project_file(file), "Helper file missing: #{file}") }
    true
  end
  
  def test_action_files_exist
    action_files = [
      'connect_eryph.rb', 'create_catlet.rb', 'destroy_catlet.rb', 'start_catlet.rb',
      'stop_catlet.rb', 'is_created.rb', 'is_stopped.rb', 'prepare_cloud_init.rb',
      'read_ssh_info.rb', 'read_state.rb', 'message_already_created.rb',
      'message_not_created.rb', 'message_will_not_destroy.rb'
    ]
    
    action_files.each do |action_file|
      full_path = "lib/vagrant-eryph/actions/#{action_file}"
      assert_file_exists(project_file(full_path), "Action file missing: #{action_file}")
    end
    true
  end
  
  def test_example_files_exist
    example_files = [
      'examples/Vagrantfile',
      'examples/Vagrantfile.windows',
      'examples/PROJECT_MANAGEMENT.md'
    ]
    
    example_files.each { |file| assert_file_exists(project_file(file), "Example file missing: #{file}") }
    true
  end
  
  def test_configuration_content
    config_file = project_file('lib/vagrant-eryph/config.rb')
    required_options = [
      'auto_config', 'enable_winrm', 'vagrant_password', 'auto_create_project',
      'parent_gene', 'project', 'fodder', 'cpu', 'memory'
    ]
    
    required_options.each do |option|
      assert_file_contains(config_file, option, "Config missing option: #{option}")
    end
    true
  end
  
  def test_cloud_init_content
    cloud_init_file = project_file('lib/vagrant-eryph/helpers/cloud_init.rb')
    required_methods = [
      'generate_linux_user_fodder', 'generate_windows_user_fodder',
      'merge_fodder_with_user_config', 'detect_os_type'
    ]
    
    required_methods.each do |method|
      assert_file_contains(cloud_init_file, method, "Cloud-init missing method: #{method}")
    end
    true
  end
  
  def test_gemspec_validity
    gemspec_file = project_file('vagrant-eryph.gemspec')
    
    # Use assert_file_contains for consistent file reading
    assert_file_contains(gemspec_file, "spec.name          = 'vagrant-eryph'", "Gemspec should set name")
    assert_file_contains(gemspec_file, "spec.version", "Gemspec should set version")
    assert_file_contains(gemspec_file, "spec.authors", "Gemspec should set authors")
    assert_file_contains(gemspec_file, "spec.summary", "Gemspec should set summary")
    assert_file_contains(gemspec_file, "eryph-compute-client", "Should depend on eryph-compute-client")
    
    true
  end
  
  def test_plugin_registration
    plugin_file = project_file('lib/vagrant-eryph/plugin.rb')
    required_registrations = [
      'provider(:eryph', 'config(:eryph', 'command(\'eryph\')'
    ]
    
    required_registrations.each do |registration|
      assert_file_contains(plugin_file, registration, "Plugin missing registration: #{registration}")
    end
    true
  end
  
  def test_localization_files
    locale_files = [
      'locales/en.yml'
    ]
    
    locale_files.each { |file| assert_file_exists(project_file(file), "Locale file missing: #{file}") }
    
    # Check if locale file has required error messages
    en_file = project_file('locales/en.yml')
    required_keys = ['vagrant_eryph:', 'errors:']
    
    required_keys.each do |key|
      assert_file_contains(en_file, key, "Locale missing key: #{key}")
    end
    
    true
  end
end