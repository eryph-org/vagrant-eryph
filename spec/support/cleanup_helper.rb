# Cleanup helper for E2E tests - inspired by ruby-client approach
module CleanupHelper
  class << self
    def final_cleanup
      puts "\n=== Final Vagrant E2E Test Cleanup ==="

      begin
        # Check if Eryph client is available
        unless defined?(Eryph)
          begin
            require 'eryph-compute'
          rescue LoadError
            puts "Warning: eryph-compute gem not available for cleanup"
            return
          end
        end

        # Try different client configurations to find one that works
        client = find_working_client

        unless client
          puts "Warning: No working client found for final cleanup"
          return
        end

        # Get all catlets and find vagrant test catlets
        cleanup_vagrant_test_catlets(client)

      rescue StandardError => e
        puts "Error during final cleanup: #{e.class}: #{e.message}"
        puts "Backtrace: #{e.backtrace.first(3).join('\n')}" if e.backtrace
      end

      puts "=== Final Cleanup Complete ===\n"
    end

    private

    def find_working_client
      client = nil

      %w[zero local default].each do |config|
        begin
          client = Eryph.compute_client(config, ssl_config: { verify_ssl: false }, scopes: %w[compute:write])
          break if client&.test_connection
        rescue StandardError
          client = nil
        end
      end

      client
    end

    def cleanup_vagrant_test_catlets(client)
      # Get all catlets and find vagrant test catlets
      catlets_response = client.catlets.catlets_list
      catlets_array = catlets_response.respond_to?(:value) ? catlets_response.value : catlets_response
      catlets_array = [catlets_array] unless catlets_array.is_a?(Array)

      # Find catlets with vagrant test naming pattern
      test_catlets = catlets_array.select do |catlet|
        catlet.name&.start_with?('vagrant-test-') ||
        catlet.name&.include?('e2e-test') ||
        catlet.name&.include?('vagrant-eryph-e2e')
      end

      if test_catlets.any?
        puts "Found #{test_catlets.length} vagrant test catlets to clean up:"

        test_catlets.each do |catlet|
          puts "  - #{catlet.name} (#{catlet.id})"
          begin
            delete_operation = client.catlets.catlets_delete(catlet.id)
            if delete_operation&.id
              puts "    Delete operation started: #{delete_operation.id}"
            else
              puts "    Warning: Delete operation returned nil"
            end
          rescue StandardError => e
            puts "    Error: Delete failed: #{e.class}: #{e.message}"
          end
        end

        puts "All delete operations submitted - cleanup will continue in background"
      else
        puts "No vagrant test catlets found - cleanup complete"
      end
    end
  end
end