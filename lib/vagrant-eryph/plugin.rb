# frozen_string_literal: true

begin
  require 'vagrant'
rescue LoadError
  raise 'The Vagrant Eryph plugin must be run within Vagrant.'
end

# This is a sanity check to make sure no one is attempting to install
# this into an early Vagrant version.
if Vagrant::VERSION < '2.0.0'
  raise 'The Vagrant Eryph plugin is only compatible with Vagrant 2.0+'
end

module VagrantPlugins
  module Eryph
    class Plugin < Vagrant.plugin('2')
      name 'Eryph'
      description <<-DESC
        This plugin installs a provider that allows Vagrant to manage
        catlets using Eryph's compute API.
      DESC

      config(:eryph, :provider) do
        require_relative 'config'
        Config
      end

      provider(:eryph, parallel: true, defaultable: false, box_optional: true) do
        require_relative 'provider'
        Provider
      end

      command('eryph') do
        require_relative 'command'
        Command
      end

      def self.setup_i18n
        # Get the gem root directory (two levels up from lib/vagrant-eryph/)
        gem_root = File.expand_path('../../..', __FILE__)
        locale_file = File.join(gem_root, 'locales', 'en.yml')
        I18n.load_path << locale_file if File.exist?(locale_file)
        I18n.reload!
      end
    end
  end
end

# Setup i18n
VagrantPlugins::Eryph::Plugin.setup_i18n
