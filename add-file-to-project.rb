#!/usr/bin/env ruby
# Usage: ruby add-file-to-project.rb path/to/file.swift [target_name]
# Adds a file to the Xcode project in the correct group structure matching the file path
# Optionally adds to specified target (e.g., MoltenTests, PerformanceTests)
# If no target specified, auto-detects based on path

require 'xcodeproj'

if ARGV.length < 1 || ARGV.length > 2
  puts "Usage: ruby add-file-to-project.rb path/to/file.swift [target_name]"
  puts "  target_name: Optional. If omitted, auto-detects from path"
  puts "  Examples:"
  puts "    ruby add-file-to-project.rb Molten/Tests/MoltenTests/MyTest.swift"
  puts "    ruby add-file-to-project.rb Molten/Tests/PerformanceTests/MyPerfTest.swift PerformanceTests"
  exit 1
end

file_path = ARGV[0]
target_name = ARGV[1]

unless File.exist?(file_path)
  puts "Error: File not found: #{file_path}"
  exit 1
end

project = Xcodeproj::Project.open('Molten.xcodeproj')

# Parse the path to create group structure
# e.g., "Molten/Tests/MoltenTests/Views/Stores/File.swift"
# -> groups: ["Molten", "Tests", "MoltenTests", "Views", "Stores"]
path_parts = file_path.split('/')
filename = path_parts.pop
group_names = path_parts

# Helper to find or create a group
def find_or_create_group(parent, name)
  group = parent.groups.find { |g| g.display_name == name }
  unless group
    # Use just the name as the path (relative to parent)
    group = parent.new_group(name, name)
    puts "  Created group: #{name}"
  end
  group
end

# Navigate/create the group hierarchy
current_group = project.main_group

group_names.each do |group_name|
  current_group = find_or_create_group(current_group, group_name)
end

# Check if file already exists in project (by filename in this group)
existing = current_group.files.find { |f| f.path == filename }
if existing
  puts "File already in project: #{filename}"
  exit 0
end

# Add the file to the final group
# new_file needs the actual file path on disk, but we'll fix the reference after
file_ref = current_group.new_file(file_path)

# Fix the file reference to use just the filename with relative source tree
file_ref.path = filename
file_ref.source_tree = '<group>'

puts "✅ Added #{filename} to project"
puts "   Group path: #{group_names.join(' > ')}"
puts "   File path: #{file_path}"

# Auto-detect target if not specified
if target_name.nil?
  if file_path.include?('/PerformanceTests/')
    target_name = 'PerformanceTests'
  elsif file_path.include?('/RepositoryTests/')
    target_name = 'RepositoryTests'
  elsif file_path.include?('/MoltenTests/')
    target_name = 'MoltenTests'
  elsif file_path.include?('/MoltenUITests/')
    target_name = 'MoltenUITests'
  elsif file_path.include?('/Molten/Sources/')
    target_name = 'Molten'
  end

  if target_name
    puts "   Auto-detected target: #{target_name}"
  end
end

# Add to target if specified or detected
if target_name
  target = project.targets.find { |t| t.name == target_name }
  if target
    target.add_file_references([file_ref])
    puts "✅ Added to target: #{target_name}"
  else
    puts "⚠️  Warning: Target '#{target_name}' not found"
    puts "   Available targets: #{project.targets.map(&:name).join(', ')}"
  end
else
  puts "⚠️  No target specified and could not auto-detect"
  puts "   Run again with target name, e.g.:"
  puts "   ruby add-file-to-project.rb #{file_path} MoltenTests"
end

project.save
puts "\n✅ Project saved"
