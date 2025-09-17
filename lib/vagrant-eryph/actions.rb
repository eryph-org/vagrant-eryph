# frozen_string_literal: true

module VagrantPlugins
  module Eryph
    module Actions
      include Vagrant::Action::Builtin

      # This action is called to halt the remote catlet.
      def self.action_halt
        Vagrant::Action::Builder.new.tap do |b|
          b.use ConfigValidate
          b.use Call, IsCreated do |env, b2|
            unless env[:result]
              b2.use MessageNotCreated
              next
            end

            b2.use ConnectEryph
            b2.use StopCatlet
          end
        end
      end

      # This action is called to terminate the remote catlet.
      def self.action_destroy
        Vagrant::Action::Builder.new.tap do |b|
          b.use Call, DestroyConfirm do |env, b2|
            if env[:result]
              b2.use ConfigValidate
              b2.use Call, IsCreated do |env2, b3|
                unless env2[:result]
                  b3.use MessageNotCreated
                  next
                end

                b3.use ConnectEryph
                b3.use ProvisionerCleanup, :before if defined?(ProvisionerCleanup)
                b3.use DestroyCatlet
              end
            else
              b2.use MessageWillNotDestroy
            end
          end
        end
      end

      # This action is called when `vagrant provision` is called.
      def self.action_provision
        Vagrant::Action::Builder.new.tap do |b|
          b.use ConfigValidate
          b.use Call, IsCreated do |env, b2|
            unless env[:result]
              b2.use MessageNotCreated
              next
            end

            b2.use Provision
          end
        end
      end

      # This action is called to read the SSH info of the machine.
      def self.action_read_ssh_info
        Vagrant::Action::Builder.new.tap do |b|
          b.use ConfigValidate
          b.use ConnectEryph
          b.use ReadSSHInfo
        end
      end

      # This action is called to read the state of the machine.
      def self.action_read_state
        Vagrant::Action::Builder.new.tap do |b|
          b.use ConfigValidate
          b.use ConnectEryph
          b.use ReadState
        end
      end

      # This action is called to SSH into the machine.
      def self.action_ssh
        Vagrant::Action::Builder.new.tap do |b|
          b.use ConfigValidate
          b.use Call, IsCreated do |env, b2|
            unless env[:result]
              b2.use MessageNotCreated
              next
            end

            b2.use SSHExec
          end
        end
      end

      def self.action_ssh_run
        Vagrant::Action::Builder.new.tap do |b|
          b.use ConfigValidate
          b.use Call, IsCreated do |env, b2|
            unless env[:result]
              b2.use MessageNotCreated
              next
            end

            b2.use SSHRun
          end
        end
      end

      def self.action_start
        Vagrant::Action::Builder.new.tap do |b|
          b.use Call, IsState, :running do |env1, b1|
            if env1[:result]
              b1.use action_provision
              next
            end

            b1.use Call, IsState, :stopped do |env2, b2|
              if env2[:result]
                b2.use action_resume
                next
              end

              b2.use Provision
              b2.use StartCatlet
              b2.use WaitForCommunicator
            end
          end
        end
      end

      def self.action_resume
        Vagrant::Action::Builder.new.tap do |b|
          b.use ConfigValidate
          b.use ConnectEryph
          b.use Call, IsCreated do |env, b2|
            unless env[:result]
              b2.use MessageNotCreated
              next
            end

            b2.use StartCatlet
            b2.use WaitForCommunicator
          end
        end
      end

      # This action is called to bring the catlet up from nothing.
      def self.action_up
        Vagrant::Action::Builder.new.tap do |b|
          b.use ConfigValidate
          b.use ConnectEryph
          b.use Call, IsCreated do |env1, b1|
            if env1[:result]
              b1.use Call, IsStopped do |env2, b2|
                if env2[:result]
                  b2.use action_start
                else
                  b2.use MessageAlreadyCreated
                end
              end
            else
              b1.use PrepareCloudInit
              b1.use CreateCatlet
              b1.use action_start
            end
          end
        end
      end

      def self.action_reload
        Vagrant::Action::Builder.new.tap do |b|
          b.use ConfigValidate
          b.use ConnectEryph
          b.use Call, IsCreated do |env, b2|
            unless env[:result]
              b2.use MessageNotCreated
              next
            end

            b2.use action_halt
            b2.use Call, IsStopped do |env2, b3|
              if env2[:result]
                b3.use action_start
              else
                # Catlet not stopped, continue anyway
                b3.use action_start
              end
            end
          end
        end
      end

      # The autoload farm
      action_root = Pathname.new(File.expand_path('actions', __dir__))
      autoload :ConnectEryph, action_root.join('connect_eryph')
      autoload :IsCreated, action_root.join('is_created')
      autoload :IsState, action_root.join('is_state')
      autoload :IsStopped, action_root.join('is_stopped')
      autoload :MessageAlreadyCreated, action_root.join('message_already_created')
      autoload :MessageNotCreated, action_root.join('message_not_created')
      autoload :MessageWillNotDestroy, action_root.join('message_will_not_destroy')
      autoload :CreateCatlet, action_root.join('create_catlet')
      autoload :DestroyCatlet, action_root.join('destroy_catlet')
      autoload :StartCatlet, action_root.join('start_catlet')
      autoload :StopCatlet, action_root.join('stop_catlet')
      autoload :PrepareCloudInit, action_root.join('prepare_cloud_init')
      autoload :ReadSSHInfo, action_root.join('read_ssh_info')
      autoload :ReadState, action_root.join('read_state')
    end
  end
end
