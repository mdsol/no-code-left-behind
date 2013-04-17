require 'optparse'

unless Kernel.respond_to?(:require_relative)
  module Kernel
    def require_relative(path)
      require File.join(File.dirname(caller[0]), path.to_str)
    end
  end
end

require_relative '../lib/atomic'
require_relative '../lib/forked'
require_relative '../lib/nuclear'
require_relative '../lib/blockable'

class Orphanator

  
  def initialize(options)
    @processed = []
    @options = options
  end
  
  def run
    # execute the merge
    if @options.has_key?(:filename)
      self.batch_process(@options[:filename])
    end
    @options[:passed_in].each do |fork|
      self.process(fork)
    end
    puts "The following forks were successfully merged - url specifies link to deletion"
    @processed.sort.each do |merged_fork|
      puts "#{merged_fork} - https://github.com/#{merged_fork}/admin#delete_repo_confirm"  
    end
  end
  
  def batch_process(file)
    # Process a number of entries, passed in a file
    if File.exist?(file)
      batcher = File.open(file)
      while (line = batcher.gets)
        begin
          if @options[:mode] == "nuclear"
            self.nucleate(line.strip) unless line.strip.empty?
          elsif @options[:mode] == "atomic"
            self.atomize(line.strip) unless line.strip.empty?
          end
        rescue AccessError => e
          puts "Access Error raised on #{line.strip} - check access: #{e.message}"
        end
      end
    end
  end
  
  def process(forked_repository)
    # Process a single entity
    if @options[:mode] == "nuclear"
      self.nucleate(forked_repository)
    elsif @options[:mode] == "atomic"
      self.atomize(forked_repository)
    end
  end
  
  protected
  
  def nucleate(forked_repository)
    # Process a single repository
    # nuclear needs single instance
    @nuclear ||= KitchenDrawer.new(@options[:timeout])
    begin
      status = @nuclear.merge_fork(forked_repository, @options[:source].nil? ? "" : @options[:source])
      if status == true
        @processed << forked_repository
      end
    rescue FissionError => e
      puts "Processing #{forked_repository} failed: #{e}"
    rescue ConnectError => e
      puts "Cannot connect using GitHub API"
      exit(1)
    end
  end
  
  def atomize(forked_repository)
    # Process a single repository
    @atomic ||= Atomic.new
    begin
      source_repo = @atomic.source_repo(repository)
      unless source_repo == repository
        @reports[repository] = ForkedReport.new(repository, source_repo)
        @reports[repository].add_local_branches(@atomic.compare_branches(repository))
        # iterate over the source branches
        @atomic.branches(source_repo).each do |branch|
          @reports[repository].add_local_commits(@atomic.compare_commits(repository, branch))
        end
      end
      @processed << forked_repository
    rescue FissionError => e
      puts "Processing #{forked_repository} failed: #{e}"
    rescue ConnectError => e
      puts "Cannot connect using GitHub API"
      exit(1)
    rescue AccessError => e
      puts "Access Error: #{e}"
      exit(1)
    end
    
  end

end

# taken from http://railsforum.com/viewtopic.php?id=19081
def numeric?(object)
  true if Float(object) rescue false
end

if __FILE__ == $0
  options = {:mode => "nuclear", 
    :timeout => 240, 
    :passed_in => [], 
    :source => nil}
  OptionParser.new do |opts|
    opts.banner = "Usage: main.rb [options]"
    
    opts.on("-m", "--mode", "Run mode") do |mode|
      unless ["nuclear", "atomic"].include?(mode)
        puts "Mode #{mode} not recognised"
        exit(1)
      end
      options[:mode] = mode
    end

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

    opts.on("-s", "--source-fork [FILENAME]", "Source for fork, to ignore the defined parent") do |filename|
      options[:source] = filename
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
