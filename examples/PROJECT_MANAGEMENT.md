# Eryph Project Management with Vagrant

The Vagrant Eryph plugin provides commands to manage Eryph projects and their configurations.

## Project Commands

### List Projects
```bash
vagrant eryph project list
```

### Create Project
```bash
# Create with default description
vagrant eryph project create my-new-project

# Create with custom description
vagrant eryph project create my-new-project --description "Development project for web app"
```

### Show Project Details
```bash
vagrant eryph project show my-project
```

### Project Network Management
```bash
# List networks in a project
vagrant eryph project network my-project --list

# Add network to project (API not yet implemented)
vagrant eryph project network my-project --add my-network

# Remove network from project (API not yet implemented)
vagrant eryph project network my-project --remove my-network
```

## Auto-Create Project Feature

By default, the plugin will automatically create projects that don't exist:

```ruby
Vagrant.configure("2") do |config|
  config.vm.provider :eryph do |eryph|
    eryph.project = "non-existent-project"    # Will be created automatically
    eryph.auto_create_project = true          # Default: true
    eryph.parent_gene = "dbosoft/ubuntu:22.04"
  end
end
```

To disable auto-creation and require explicit project creation:

```ruby
Vagrant.configure("2") do |config|
  config.vm.provider :eryph do |eryph|
    eryph.project = "existing-project"        # Must exist
    eryph.auto_create_project = false         # Disable auto-creation
    eryph.parent_gene = "dbosoft/ubuntu:22.04"
  end
end
```

## Workflow Examples

### 1. Create Project and Launch Catlet
```bash
# Create the project explicitly
vagrant eryph project create web-dev --description "Web development environment"

# Configure Vagrantfile to use the project
# eryph.project = "web-dev"
# eryph.auto_create_project = false  # Since we created it manually

# Launch the catlet
vagrant up --provider=eryph
```

### 2. Let Vagrant Auto-Create Project
```bash
# Just run vagrant up with auto_create_project enabled (default)
# The project will be created automatically if it doesn't exist
vagrant up --provider=eryph
```

### 3. Multi-Machine Setup with Shared Project
```ruby
Vagrant.configure("2") do |config|
  # All machines will share the same project
  project_name = "multi-tier-app"
  
  # Web server
  config.vm.define "web" do |web|
    web.vm.provider :eryph do |eryph|
      eryph.project = project_name
      eryph.parent_gene = "dbosoft/ubuntu:22.04"
      eryph.auto_create_project = true  # Only first machine needs to create
    end
  end
  
  # Database server
  config.vm.define "db" do |db|
    db.vm.provider :eryph do |eryph|
      eryph.project = project_name        # Same project
      eryph.parent_gene = "dbosoft/postgresql:15"
      eryph.auto_create_project = false   # Project should exist by now
    end
  end
end
```

### 4. Project Management Workflow
```bash
# List all projects
vagrant eryph project list

# Show details of a specific project
vagrant eryph project show my-project

# Check project networks (future feature)
vagrant eryph project network my-project --list

# Create a new project for a different environment
vagrant eryph project create staging --description "Staging environment"
```

## Notes

- Project creation happens during the connection phase, before catlet creation
- Project names must be unique within your Eryph installation
- The auto-created projects get a default description indicating they were created by Vagrant
- Network management commands are prepared but depend on the Eryph API implementation
- All commands respect your Eryph credential configuration (local → user → global lookup)