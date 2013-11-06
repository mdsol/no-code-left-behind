#TODO: Implement the listener/logger

module Scribe
  
  def add_listener(listener)
    listeners << listener
  end
  
  def notify(message)
    listeners.each do |listener|
      listener.write message
    end
  end
  
  protected
  
  def listeners
    @listeners ||= []
  end
  
end