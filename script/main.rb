require 'atomic'
require 'forked'
require 'nuclear'
require 'optparse'

class Orphanator

  
  def initialize(options)
    @processed = []
    @options = options
  end
  
  def run
    if @options.has_key?(:filename)
      self.batch_process(@options[:filename])
    end
    @options[:arguments].each do |fork|
      self.process(fork)
    end
    puts "The following forks were successfully merged"
    @processed.sort.each do |merged_fork|
      p "#{merged_fork} - https://github.com/#{merged_fork}/admin#delete_repo_confirm"  
    end
    p "Please follow the above links to remove the repository"
  end
  
  def batch_process(file)
    """
    Process a number of entries, passed in a file
    """
    if File.exist?(file)
      batcher = File.open(file)
      while (line = batcher.gets)
        if @options[:mode] == "nuclear"
          self.nucleate(line)
        elsif @options[:mode] == "atomic"
          self.atomize(line)
        end
    end
  end
  
  def process(forked_repository)
    """
    Process a single entity
    """
    if @options[:mode] == "nuclear"
      self.nucleate(line)
    elsif @options[:mode] == "atomic"
      self.atomize(line)
    end
  end
  
  protected
  
  def nucleate(forked_repository)
    """
    Process a single repository
    """
    # nuclear needs single instance
    @nuclear ||= Nuclear.new(@options[:timeout])
    begin
      @nuclear.merge_fork(forked_repository)
      @processed << forked_repository
    rescue FissionError => e
      puts "Processing #{forked_repository} failed: #{e}"
    end
  end
  
  def atomize(forked_repository)
    """
    Process a single repository
    """
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
    end
    
  end

end

# taken from http://railsforum.com/viewtopic.php?id=19081
def numeric?(object)
  true if Float(object) rescue false
end

if __FILE__ == $0
  options = {:mode => "nuclear", :timeout => 240}
  OptionParser.new do |opts|
    opts.banner = "Usage: main.rb [options]"
    
    opts.on("-m", "--mode", "Run mode") do |mode|
      unless ["nuclear", "atomic"].include?(mode)
        puts "Mode #{mode} not recognised"
        exit(1)
      end
      options[:mode] = mode
    end

    opts.on("-f", "--file-batch", "File containing list of fork") do |filename|
      unless File.exist?(filename)
        puts "File #{filename} not found, exiting"
        exit(1)
      end
      options[:filename] = filename
    end
    
    opts.on("-t", "--git-timeout", "Timeout for Git operations") do |timeout|
      if numeric?(timeout)
        options[:timeout] = timeout.to_i
      else
        puts "Specified timeout #{timeout} is not a valid number"
        exit(1)
      end
    end
    
  end.parse!
  
  
end