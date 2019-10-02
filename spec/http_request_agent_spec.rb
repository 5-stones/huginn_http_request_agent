require 'rails_helper'
require 'huginn_agent/spec_helper'

describe Agents::HttpRequestAgent do
  before(:each) do
    @valid_options = Agents::HttpRequestAgent.new.default_options
    @checker = Agents::HttpRequestAgent.new(:name => "HttpRequestAgent", :options => @valid_options)
    @checker.user = users(:bob)
    @checker.save!
  end

  pending "add specs here"
end
