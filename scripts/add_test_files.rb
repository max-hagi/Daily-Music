require 'xcodeproj'

path = 'Daily Music.xcodeproj'
project = Xcodeproj::Project.open(path)
test = project.targets.find { |t| t.name == 'Daily MusicTests' }
raise 'test target not found' unless test

group = project.main_group.find_subpath('Daily MusicTests', true)

ARGV.each do |rel|
  base = File.basename(rel)
  already = test.source_build_phase.files_references.any? { |fr| fr && fr.path && fr.path.end_with?(base) }
  if already
    puts "skip (already present): #{rel}"
    next
  end
  ref = group.new_file(rel)
  test.add_file_references([ref])
  puts "added: #{rel}"
end

project.save
puts 'OK'
