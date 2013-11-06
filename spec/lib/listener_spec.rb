require 'listener'

class Scribable
  include Scribe
end

describe Scribe do

  subject(:scribe) {Scribable.new}
  let(:user) {'someUser'}
  let(:io) {double('IO')}

  before :each do
    scribe.add_listener(io)
  end
  
  describe "#notify" do
    
    it "writes a message to the configured listener"  do
      io.should_receive(:write).with("Some message")
      scribe.notify "Some message"
    end
    
  end
  
  describe "#add_listener" do
    let(:listener) {double('Listener')}

    it "adds a listener to a scribe" do
      listener.should_receive(:write).with("Some message")
      io.should_receive(:write).with("Some message")
      scribe.add_listener(listener)
      scribe.notify "Some message"
    end
    
  end
  
end
