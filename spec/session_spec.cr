require "./spec_helper"

describe FIX::Session do
  it "initialize" do
    serv = TCPServer.new(9898)
    session = FIX::Session.new "localhost", 9898
    session.should be_a(FIX::Session)
    serv.close
  end
end
