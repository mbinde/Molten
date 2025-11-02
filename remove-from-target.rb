#!/usr/bin/env ruby
# remove-from-target.rb
# Removes test files from the main app target (keeps them in test targets only)
#
# Usage:
#   ruby remove-from-target.rb path/to/TestFile.swift target_to_remove_from

require 'xcodeproj'

if ARGV.length < 2
  puts "Usage: ruby remove-from-target.rb path/to/TestFile.swift target_name"
  puts "Example: ruby remove-from-target.rb Molten/Tests/MoltenTests/MyTest.swift Molten"
  exit 1
end

test_file_path = ARGV[0]
target_name_to_remove = ARGV[1]

# Open the project
project_path = 'Molten.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the target to remove from
target = project.targets.find { |t| t.name == target_name_to_remove }

unless target
  puts "Error: #{target_name_to_remove} target not found"
  puts "Available targets: #{project.targets.map(&:name).join(', ')}"
  exit 1
end

puts "Removing from target: #{target_name_to_remove}"

# Get relative path
project_root = File.expand_path(Dir.pwd)
absolute_path = File.expand_path(test_file_path)
relative_path = Pathname.new(absolute_path).relative_path_from(Pathname.new(project_root)).to_s

# Find the file reference
file_ref = project.files.find { |f| f.path == relative_path }

unless file_ref
  puts "Error: File not found in project: #{relative_path}"
  exit 1
end

# Remove from target
build_files = target.source_build_phase.files.select { |bf| bf.file_ref == file_ref }

if build_files.empty?
  puts "File not in #{target_name_to_remove} target"
else
  build_files.each do |build_file|
    target.source_build_phase.files.delete(build_file)
  end
  puts "✅ Removed #{relative_path} from #{target_name_to_remove} target"
end

# Save the project
project.save
puts "✅ Project saved successfully"
