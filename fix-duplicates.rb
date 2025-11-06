#!/usr/bin/env ruby
# fix-duplicates.rb
# Removes duplicate file references from Xcode project

require 'xcodeproj'

project_path = 'Molten.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the MoltenTests target
target = project.targets.find { |t| t.name == 'MoltenTests' }

unless target
  puts "Error: MoltenTests target not found"
  exit 1
end

# Files that have duplicates
duplicate_files = [
  'KilnScheduleRepositoryErrorsTests.swift',
  'ToolItemDataLoadingServiceTests.swift',
  'DecimalFormattingTests.swift',
  'ServiceTypeTests.swift',
  'ServiceValidationTests.swift',
  'TagColorMappingTests.swift',
  'ProjectRepositoryErrorsTests.swift'
]

puts "Removing duplicate build file references..."

duplicate_files.each do |filename|
  # Find all build files for this filename
  build_files = target.source_build_phase.files.select do |build_file|
    build_file.file_ref && build_file.file_ref.path && build_file.file_ref.path.end_with?(filename)
  end

  if build_files.count > 1
    puts "Found #{build_files.count} references to #{filename}, removing duplicates..."
    # Keep the first, remove the rest
    build_files[1..-1].each do |duplicate|
      target.source_build_phase.files.delete(duplicate)
    end
    puts "  ✅ Removed #{build_files.count - 1} duplicate(s) for #{filename}"
  elsif build_files.count == 1
    puts "  ℹ️  #{filename} has no duplicates"
  else
    puts "  ⚠️  #{filename} not found in build phase"
  end
end

# Save the project
project.save
puts "\n✅ Project saved successfully"
