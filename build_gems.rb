#!/usr/bin/env ruby

require 'fileutils'

# Copy the fixed ruby-client files to temp directory for building
puts "Creating temporary build directories..."
FileUtils.mkdir_p('temp_build/clientruntime/lib/eryph')
FileUtils.mkdir_p('temp_build/compute/lib/eryph')

# Copy clientruntime files
puts "Copying clientruntime files..."
FileUtils.cp_r('../ruby-client/lib/eryph/clientruntime.rb', 'temp_build/clientruntime/lib/eryph/')
FileUtils.cp_r('../ruby-client/lib/eryph/clientruntime', 'temp_build/clientruntime/lib/eryph/')
FileUtils.cp('../ruby-client/eryph-clientruntime.gemspec', 'temp_build/clientruntime/')
FileUtils.cp('../ruby-client/README.md', 'temp_build/clientruntime/')
FileUtils.cp('../ruby-client/LICENSE', 'temp_build/clientruntime/')

# Copy compute client files
puts "Copying compute client files..."
FileUtils.cp_r('../ruby-client/lib/eryph/compute.rb', 'temp_build/compute/lib/eryph/')
FileUtils.cp_r('../ruby-client/lib/eryph/compute', 'temp_build/compute/lib/eryph/')
FileUtils.cp('../ruby-client/eryph-compute.gemspec', 'temp_build/compute/')
FileUtils.cp('../ruby-client/README.md', 'temp_build/compute/')
FileUtils.cp('../ruby-client/LICENSE', 'temp_build/compute/')

# Build the gems
puts "Building clientruntime gem..."
Dir.chdir('temp_build/clientruntime') do
  system('gem build eryph-clientruntime.gemspec')
  FileUtils.mv(Dir.glob('*.gem'), '../../')
end

puts "Building compute client gem..."
Dir.chdir('temp_build/compute') do
  system('gem build eryph-compute.gemspec')
  FileUtils.mv(Dir.glob('*.gem'), '../../')
end

# Clean up
puts "Cleaning up..."
FileUtils.rm_rf('temp_build')

puts "Gems built successfully!"
Dir.glob('eryph-*.gem').each { |gem| puts "  #{gem}" }