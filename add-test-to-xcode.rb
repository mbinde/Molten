#!/usr/bin/env ruby
# add-test-to-xcode.rb
# Programmatically adds test files to MoltenTests target
#
# Usage: ruby add-test-to-xcode.rb path/to/TestFile.swift

require 'xcodeproj'

if ARGV.empty?
  puts "Usage: ruby add-test-to-xcode.rb path/to/TestFile.swift"
  exit 1
end

test_file_path = ARGV[0]

unless File.exist?(test_file_path)
  puts "Error: File not found: #{test_file_path}"
  exit 1
end

# Open the project
project_path = 'Molten.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the MoltenTests target
molten_tests_target = project.targets.find { |t| t.name == 'MoltenTests' }

unless molten_tests_target
  puts "Error: MoltenTests target not found"
  exit 1
end

# Get relative path from project root
relative_path = Pathname.new(test_file_path).relative_path_from(Pathname.new(Dir.pwd)).to_s

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

  # Navigate/create group hierarchy
  path_components[0...-1].each do |component|
    group = group.find_subpath(component, true)
  end

  # Add file reference
  file_ref = group.new_file(relative_path)
  puts "Added file to project: #{relative_path}"
end

# Add to MoltenTests target if not already there
unless molten_tests_target.source_build_phase.files_references.include?(file_ref)
  molten_tests_target.add_file_references([file_ref])
  puts "Added #{relative_path} to MoltenTests target"
else
  puts "File already in MoltenTests target"
end

# Save the project
project.save
puts "✅ Project saved successfully"
