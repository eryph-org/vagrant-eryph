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
    end
  end
end