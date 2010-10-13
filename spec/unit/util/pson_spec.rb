#!/usr/bin/env ruby

Dir.chdir(File.dirname(__FILE__)) { (s = lambda { |f| File.exist?(f) ? require(f) : Dir.chdir("..") { s.call(f) } }).call("spec/spec_helper.rb") }

require 'puppet/util/pson'

class PsonUtil
  include Puppet::Util::Pson
end

describe Puppet::Util::Pson do
  it "should fail if no data is provided" do
    lambda { PsonUtil.new.pson_create("type" => "foo") }.should raise_error(ArgumentError)
  end

  it "should call 'from_pson' with the provided data" do
    pson = PsonUtil.new
    pson.expects(:from_pson).with("mydata")
    pson.pson_create("type" => "foo", "data" => "mydata")
  end


  { 
    'foo' => '"foo"',
    1 => '1',
    "\x80" => "\"\x80\"",
    [] => '[]'
  }.each { |str,pson|
    it "should be able to encode #{str.inspect}" do
      str.to_pson.should == pson
    end
  }

  it "should be able to handle arbitrary binary data" do
    bin_string = (1..20000).collect { |i| ((17*i+13*i*i) % 255).chr }.join
    PSON.parse(%Q{{ "type": "foo", "data": #{bin_string.to_pson} }})["data"].should == bin_string
  end
end
