#!/usr/bin/env ruby
require "digest/sha1"
require "json"
require "fileutils"

class ClientFilesManifestGenetrator
  def scan(root_dir, data_storage_dir = nil)
    @copy = !!data_storage_dir
    if @copy
      @storage_dir = File.absolute_path(data_storage_dir)
      FileUtils.rm_rf(@storage_dir)
      FileUtils.mkdir_p(@storage_dir)
    end
    
    Dir.chdir root_dir do
      proccess_dir
    end
  end
  
  private
  
  def proccess_dir(dir = "")
    array = []
    dir = dir + "/" if dir != ""
    
    Dir.glob(dir + "*").each do |entry|      
      if File.directory?(entry)
        array += proccess_dir(entry)
        next
      end
      
      hashsum = nil
      type = nil
      filepath = entry
      
      if type.nil? && filepath =~ /\.erb\z/
        filepath.sub(/\.erb\z/, "")
        type = :redownload
      end
      if type.nil? && File.file?(entry)
        type = :file
        hashsum = Digest::SHA1.file(entry).hexdigest.upcase
      end
      
      FileUtils.copy(entry, File.join(@storage_dir, hashsum)) if @copy && !hashsum.nil?
      
      puts hashsum + " | " + entry
      array << { path: filepath, hashsum: hashsum, type: type }
    end
    array
  end
  
  def self.export_to_json(filename, hash_data)
    File.open filename, "w" do |f|
      f.write JSON.pretty_generate(hash_data)
    end
  end
  
  def self.generate(source_path, output_path, storage_path = File.join(output_path, "files"))
    generator = self.new
    manifest = generator.scan(source_path, storage_path)
    export_to_json(File.join(output_path, "manifest.json"), manifest)
  end
end


if $0 == __FILE__
  require "thor"

  class ThorCommand < Thor
    SCRIPT_ROOT = File.absolute_path(File.dirname(__FILE__))
    class_option :output, :type => :string, :default => "#{SCRIPT_ROOT}/output/", :aliases => "-o"
    class_option :common_dir, :type => :string, :default => "#{SCRIPT_ROOT}/common/", :aliases => "-c"
    class_option :versions_dir, :type => :string, :default => "#{SCRIPT_ROOT}/versions/", :aliases => "-v"
  
    desc "all", "Generate all manifests"
    def all      
      invoke :common, [], { :output => File.join(options[:output], "common") }
      
      Dir.entries(options[:versions_dir]).each do |version|
        next if version[0,1] == "."
        puts # make a newline for readability
        invoke :client, [version], { :output => File.join(options[:output], "versions", version) }
        forget_last_invocation
      end
    end
    
    desc "common", "Generate common files manifest"
    def common
      puts "Generating manifest for common files"
      path = options[:common_dir]
      ClientFilesManifestGenetrator.generate(path, options[:output])
    end
    
    desc "client client_version", "Generate a particular client manifest"
    def client(client_version)
      puts "Generating manifest for #{client_version} client"
      path = File.join(options[:versions_dir], client_version)
      ClientFilesManifestGenetrator.generate(path, options[:output])
    end
    
    no_tasks do
      def forget_last_invocation
        @_invocations[self.class].pop
      end
    end
  end
  
  puts "Client Files Manifest Generator 2"
  ThorCommand.start
end