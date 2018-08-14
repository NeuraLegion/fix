require "./spec_helper"

describe FIX::Session do
  it "initialize" do
    session = FIX::Session.new
    session.should be_a(FIX::Session)
  end
end
