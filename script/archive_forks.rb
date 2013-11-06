
require_relative '../lib/archiver'
require 'optparse'

class Orphanator

  attr_accessor :processed
  attr_reader :options

  def initialize(options)
    @processed = []
    @options = options
  end

  def run
    # execute the merge
    if options.has_key?(:filename)
      self.batch_process(options[:filename])
    end
    options[:passed_in].each do |fork|
      begin
        archiver = Archiver.new(options.merge({repository: fork}))
        archiver.archive
        unless archiver.needs_archiving?
          # only put across the successfully archived branch
          processed << fork
        end
      rescue ArchivingError => e
        puts "Merging #{fork} failed with exception: #{e.message}"
      end
    end
    unless processed.empty?
      puts "The following forks were successfully merged - url specifies link to deletion"
      processed.each do | merged_fork |
        puts "#{merged_fork} - https://github.com/#{merged_fork}/admin#delete_repo_confirm"
      end
    end
  end

  def batch_process(file)
    # Process a number of entries, passed in a file
    if File.exist?(file)
      batcher = File.open(file)
      while (fork = batcher.gets)
        begin
          archiver = Archiver.new(options.merge({repository: fork}))
          archiver.archive
          unless archiver.needs_archiving?
            processed << fork
          end
        rescue AccessError => e
          puts "Access Error raised on #{line.strip} - check access: #{e.message}"
        rescue ArchivingError => e
          puts "Merging #{fork} failed with exception: #{e.message}"
        end
      end
    end
  end

end

# taken from http://railsforum.com/viewtopic.php?id=19081
def numeric?(object)
  true if Float(object) rescue false
end

if __FILE__ == $0
  options = {:timeout => 240,
    :passed_in => []}
  OptionParser.new do |opts|
    opts.banner = "Usage: archive_forks.rb [options]"
    
    opts.on("-f", "--file [FILENAME]", "File containing list of fork") do |filename|
      unless File.exist?(filename)
        puts "File #{filename} not found, exiting"
        exit(1)
      end
      options[:filename] = filename
    end
    
    opts.on("-t", "--git-timeout [TIMEOUT]", "Timeout for Git operations") do |timeout|
      if numeric?(timeout)
        options[:timeout] = timeout.to_i
      else
        puts "Specified timeout #{timeout} is not a valid number"
        exit(1)
      end
    end


  end.parse!
  
  # remainder goes into :passed_in
  options[:passed_in] = ARGV

  if not (options[:passed_in].empty? && options.fetch(:filename, nil).nil?)
    orphanator = Orphanator.new(options)
    orphanator.run
  elsif (options[:source] && options[:passed_in].length == 1)
    orphanator = Orphanator.new(options)
    orphanator.run
  else
    puts "Nothing to do"
  end
end
