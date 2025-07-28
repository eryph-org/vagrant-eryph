require 'spec_helper'

RSpec.describe 'Plugin Structure' do
  let(:project_root) { File.expand_path('..', __dir__) }
  
  def project_file(path)
    File.join(project_root, path)
  end

  describe 'core files' do
    let(:core_files) do
      [
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
    end

    it 'all core files exist' do
      core_files.each do |file|
        file_path = project_file(file)
        expect(File.exist?(file_path)).to be(true)
      end
    end
  end

  describe 'helper files' do
    let(:helper_files) do
      [
        'lib/vagrant-eryph/helpers/cloud_init.rb',
        'lib/vagrant-eryph/helpers/ssh_key.rb',
        'lib/vagrant-eryph/helpers/eryph_client.rb'
      ]
    end

    it 'all helper files exist' do
      helper_files.each do |file|
        file_path = project_file(file)
        expect(File.exist?(file_path)).to be(true)
      end
    end
  end

  describe 'action files' do
    let(:action_files) do
      [
        'connect_eryph.rb', 'create_catlet.rb', 'destroy_catlet.rb', 'start_catlet.rb',
        'stop_catlet.rb', 'is_created.rb', 'is_stopped.rb', 'prepare_cloud_init.rb',
        'read_ssh_info.rb', 'read_state.rb', 'message_already_created.rb',
        'message_not_created.rb', 'message_will_not_destroy.rb'
      ]
    end

    it 'all action files exist' do
      action_files.each do |action_file|
        full_path = project_file("lib/vagrant-eryph/actions/#{action_file}")
        expect(File.exist?(full_path)).to be(true)
      end
    end
  end

  describe 'example files' do
    let(:example_files) do
      [
        'examples/Vagrantfile',
        'examples/Vagrantfile.windows',
        'examples/PROJECT_MANAGEMENT.md'
      ]
    end

    it 'all example files exist' do
      example_files.each do |file|
        file_path = project_file(file)
        expect(File.exist?(file_path)).to be(true)
      end
    end
  end

  describe 'configuration content' do
    let(:config_file) { project_file('lib/vagrant-eryph/config.rb') }
    let(:required_options) do
      [
        'auto_config', 'enable_winrm', 'vagrant_password', 'auto_create_project',
        'parent_gene', 'project', 'fodder', 'cpu', 'memory', 'catlet'
      ]
    end

    it 'config file contains all required options' do
      expect(File.exist?(config_file)).to be true
      content = File.read(config_file)
      
      required_options.each do |option|
        expect(content).to include(option), "Config missing option: #{option}"
      end
    end
  end

  describe 'cloud-init content' do
    let(:cloud_init_file) { project_file('lib/vagrant-eryph/helpers/cloud_init.rb') }
    let(:required_methods) do
      [
        'generate_linux_user_fodder', 'generate_windows_user_fodder',
        'merge_fodder_with_user_config', 'detect_os_type'
      ]
    end

    it 'cloud-init helper contains required methods' do
      expect(File.exist?(cloud_init_file)).to be true
      content = File.read(cloud_init_file)
      
      required_methods.each do |method|
        expect(content).to include(method), "Cloud-init missing method: #{method}"
      end
    end
  end

  describe 'gemspec validity' do
    let(:gemspec_file) { project_file('vagrant-eryph.gemspec') }

    it 'gemspec contains required fields' do
      expect(File.exist?(gemspec_file)).to be true
      content = File.read(gemspec_file)
      
      expect(content).to include("spec.name          = 'vagrant-eryph'")
      expect(content).to include('spec.version')
      expect(content).to include('spec.authors')
      expect(content).to include('spec.summary')
      expect(content).to include('eryph-compute-client')
    end
  end

  describe 'plugin registration' do
    let(:plugin_file) { project_file('lib/vagrant-eryph/plugin.rb') }
    let(:required_registrations) do
      ['provider(:eryph', 'config(:eryph', 'command(\'eryph\')']
    end

    it 'plugin file contains required registrations' do
      expect(File.exist?(plugin_file)).to be true
      content = File.read(plugin_file)
      
      required_registrations.each do |registration|
        expect(content).to include(registration), "Plugin missing registration: #{registration}"
      end
    end
  end

  describe 'localization files' do
    let(:locale_files) { ['locales/en.yml'] }
    let(:en_file) { project_file('locales/en.yml') }

    it 'all locale files exist' do
      locale_files.each do |file|
        file_path = project_file(file)
        expect(File.exist?(file_path)).to be(true)
      end
    end

    it 'English locale contains required keys' do
      expect(File.exist?(en_file)).to be true
      content = File.read(en_file)
      
      required_keys = ['vagrant_eryph:', 'errors:']
      required_keys.each do |key|
        expect(content).to include(key), "Locale missing key: #{key}"
      end
    end
  end
end