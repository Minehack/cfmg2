require "json"

collection_dir = "collect"
output_dir = "output"

system "rm -r \"#{collection_dir}\""
Dir.mkdir(collection_dir) unless File.directory?(collection_dir)
Dir.mkdir(File.join(collection_dir, "files")) unless File.directory?(File.join(collection_dir, "files"))

common_files = JSON.load(File.open(File.join(output_dir, "common", "manifest.json")))

Dir[File.join(output_dir, "versions", "*")].each do |path|
  version = path.sub(/^.*\//, "")
  client_files = JSON.load(File.open(File.join(path, "manifest.json")))
  all_files = common_files + client_files
  File.open(File.join(collection_dir, "#{version}.json"), "w") do |file|
    file <<  JSON.pretty_generate(all_files)
  end
  
  puts "Version #{version}: #{all_files.size} (#{common_files.size} + #{client_files.size}) files"
  
  count = Dir[File.join(path, "files", "*")].inject(0) do |counter, file|
    system "cp \"#{file}\" \"#{File.join(collection_dir, "files")}\""
    counter += 1
  end
  puts "... #{count} file(s) copied!"
end

