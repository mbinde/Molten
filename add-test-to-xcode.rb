#!/usr/bin/env ruby
# add-test-to-xcode.rb
# Programmatically adds test files to test targets (MoltenTests or MoltenUITests)
#
# Usage:
#   ruby add-test-to-xcode.rb path/to/TestFile.swift [target_name]
#
# Examples:
#   ruby add-test-to-xcode.rb Tests/MoltenTests/MyTest.swift
#   ruby add-test-to-xcode.rb Tests/MoltenUITests/MyUITest.swift MoltenUITests

require 'xcodeproj'

if ARGV.empty?
  puts "Usage: ruby add-test-to-xcode.rb path/to/TestFile.swift [target_name]"
  puts "  target_name: MoltenTests (default) or MoltenUITests"
  exit 1
end

test_file_path = ARGV[0]
target_name = ARGV[1] || 'MoltenTests'  # Default to MoltenTests

# Auto-detect target from path if not specified
if ARGV[1].nil?
  if test_file_path.include?('MoltenUITests')
    target_name = 'MoltenUITests'
  elsif test_file_path.include?('RepositoryTests')
    target_name = 'RepositoryTests'
  else
    target_name = 'MoltenTests'
  end
end

# Convert to absolute path first to ensure file exists
absolute_path = File.expand_path(test_file_path)

unless File.exist?(absolute_path)
  puts "Error: File not found: #{absolute_path}"
  exit 1
end

# Open the project
project_path = 'Molten.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the target
target = project.targets.find { |t| t.name == target_name }

unless target
  puts "Error: #{target_name} target not found"
  puts "Available targets: #{project.targets.map(&:name).join(', ')}"
  exit 1
end

puts "Using target: #{target_name}"

# Get relative path from project root
project_root = File.expand_path(Dir.pwd)
relative_path = Pathname.new(absolute_path).relative_path_from(Pathname.new(project_root)).to_s

# Check if file already in project
existing_file = project.files.find { |f| f.path == relative_path }

if existing_file
  puts "File already in project: #{relative_path}"
  file_ref = existing_file
else
  # Add file to project
  # Determine the group based on path
  group = project.main_group
  path_components = relative_path.split('/')

  # Navigate/create group hierarchy (handling different group types)
  path_components[0...-1].each do |component|
    # Check if group supports find_subpath (regular PBXGroup)
    if group.respond_to?(:find_subpath)
      group = group.find_subpath(component, true)
    elsif group.respond_to?(:children)
      # For groups that don't support find_subpath, try to find or create child
      child = group.children.find { |c| c.display_name == component || c.path == component }
      if child.nil?
        # Create new group if it doesn't exist
        child = group.new_group(component)
      end
      group = child
    else
      # If we can't navigate, just use main group
      puts "Warning: Cannot navigate to #{component}, using main group"
      group = project.main_group
      break
    end
  end

  # Add file reference
  file_ref = group.new_file(relative_path)
  puts "Added file to project: #{relative_path}"
end

# Add to target if not already there
unless target.source_build_phase.files_references.include?(file_ref)
  target.add_file_references([file_ref])
  puts "Added #{relative_path} to #{target_name} target"
else
  puts "File already in #{target_name} target"
end

# Save the project
project.save
puts "✅ Project saved successfully"
