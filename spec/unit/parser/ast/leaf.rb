#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../../spec_helper'

describe Puppet::Parser::AST::Leaf do
    before :each do
        @scope = stub 'scope'
        @value = stub 'value'
        @leaf = Puppet::Parser::AST::Leaf.new(:value => @value)
    end

    it "should have a evaluate_match method" do
        Puppet::Parser::AST::Leaf.new(:value => "value").should respond_to(:evaluate_match)
    end

    describe "when evaluate_match is called" do
        it "should evaluate itself" do
            @leaf.expects(:safeevaluate)
            @leaf.evaluate_match("value")
        end

        it "should match values by equality" do
            @value.stubs(:==).returns(false)
            @leaf.stubs(:safeevaluate).returns(@value)
            @value.expects(:==).with("value")

            @leaf.evaluate_match("value")
        end

        it "should downcase the evaluated value if wanted" do
            @leaf.stubs(:safeevaluate).returns(@value)
            @value.expects(:downcase).returns("value")

            @leaf.evaluate_match("value", :insensitive => true)
        end

        it "should match undef if value is an empty string" do
            @leaf.stubs(:safeevaluate).returns("")

            @leaf.evaluate_match(:undef).should be_true
        end
    end

    describe "when converting to string" do
        it "should transform its value to string" do
            value = stub 'value', :is_a? => true
            value.expects(:to_s)
            Puppet::Parser::AST::Leaf.new( :value => value ).to_s
        end
    end

    it "should have a match method" do
        @leaf.should respond_to(:match)
    end

    it "should delegate match to ==" do
        @value.expects(:==).with("value")

        @leaf.match("value")
    end
end

describe Puppet::Parser::AST::FlatString do
    describe "when converting to string" do
        it "should transform its value to a quoted string" do
            value = stub 'value', :is_a? => true, :to_s => "ab"
            Puppet::Parser::AST::FlatString.new( :value => value ).to_s.should == "\"ab\""
        end
    end
end

describe Puppet::Parser::AST::String do
    describe "when converting to string" do
        it "should transform its value to a quoted string" do
            value = stub 'value', :is_a? => true, :to_s => "ab"
            Puppet::Parser::AST::String.new( :value => value ).to_s.should == "\"ab\""
        end
    end
end

describe Puppet::Parser::AST::Undef do
    before :each do
        @scope = stub 'scope'
        @undef = Puppet::Parser::AST::Undef.new(:value => :undef)
    end

    it "should match undef with undef" do
        @undef.evaluate_match(:undef).should be_true
    end

    it "should not match undef with an empty string" do
        @undef.evaluate_match("").should be_false
    end
end

describe Puppet::Parser::AST::Regex do
    before :each do
        @scope = stub 'scope'
    end

    describe "when initializing" do
        it "should create a Regexp with its content when value is not a Regexp" do
            Regexp.expects(:new).with("/ab/")

            Puppet::Parser::AST::Regex.new :value => "/ab/"
        end

        it "should not create a Regexp with its content when value is a Regexp" do
            value = Regexp.new("/ab/")
            Regexp.expects(:new).with("/ab/").never

            Puppet::Parser::AST::Regex.new :value => value
        end
    end

    describe "when evaluating" do
        it "should return self" do
            val = Puppet::Parser::AST::Regex.new :value => "/ab/"

            val.evaluate.should === val
        end
    end

    describe "when evaluate_match" do
        before :each do
            @value = stub 'regex'
            @value.stubs(:match).with("value").returns(true)
            Regexp.stubs(:new).returns(@value)
            @regex = Puppet::Parser::AST::Regex.new :value => "/ab/"
        end

        it "should issue the regexp match" do
            @value.expects(:match).with("value")

            @regex.evaluate_match("value")
        end

        it "should set ephemeral scope vars if there is a match" do
            @scope.expects(:ephemeral_from).with(true, nil, nil)

            @regex.evaluate_match("value")
        end

        it "should return the match to the caller" do
            @value.stubs(:match).with("value").returns(:match)
            @scope.stubs(:ephemeral_from)

            @regex.evaluate_match("value")
        end
    end

    it "should return the regex source with to_s" do
        regex = stub 'regex'
        Regexp.stubs(:new).returns(regex)

        val = Puppet::Parser::AST::Regex.new :value => "/ab/"

        regex.expects(:source)

        val.to_s
    end

    it "should delegate match to the underlying regexp match method" do
        regex = Regexp.new("/ab/")
        val = Puppet::Parser::AST::Regex.new :value => regex

        regex.expects(:match).with("value")

        val.match("value")
    end
end

describe Puppet::Parser::AST::Variable do
    before :each do
        @scope = stub 'scope'
        @var = Puppet::Parser::AST::Variable.new(:value => "myvar")
    end

    it "should lookup the variable in scope" do
        @scope.expects(:lookupvar).with("myvar", false).returns(:myvalue)
        @var.safeevaluate.should == :myvalue
    end

    it "should return undef if the variable wasn't set" do
        @scope.expects(:lookupvar).with("myvar", false).returns(:undefined)
        @var.safeevaluate.should == :undef
    end

    describe "when converting to string" do
        it "should transform its value to a variable" do
            value = stub 'value', :is_a? => true, :to_s => "myvar"
            Puppet::Parser::AST::Variable.new( :value => value ).to_s.should == "\$myvar"
        end
    end
end

describe Puppet::Parser::AST::HostName do
    before :each do
        @scope = stub 'scope'
        @value = stub 'value', :=~ => false
        @value.stubs(:to_s).returns(@value)
        @value.stubs(:downcase).returns(@value)
        @host = Puppet::Parser::AST::HostName.new( :value => @value)
    end

    it "should raise an error if hostname is not valid" do
        lambda { Puppet::Parser::AST::HostName.new( :value => "not an hostname!" ) }.should raise_error
    end

    it "should not raise an error if hostname is a regex" do
        lambda { Puppet::Parser::AST::HostName.new( :value => Puppet::Parser::AST::Regex.new(:value => "/test/") ) }.should_not raise_error
    end

    it "should stringify the value" do
        value = stub 'value', :=~ => false

        value.expects(:to_s).returns("test")

        Puppet::Parser::AST::HostName.new(:value => value)
    end

    it "should downcase the value" do
        value = stub 'value', :=~ => false
        value.stubs(:to_s).returns("UPCASED")
        host = Puppet::Parser::AST::HostName.new(:value => value)

        host.value == "upcased"
    end

    it "should evaluate to its value" do
        @host.evaluate.should == @value
    end

    it "should delegate eql? to the underlying value if it is an HostName" do
        @value.expects(:eql?).with("value")
        @host.eql?("value")
    end

    it "should delegate eql? to the underlying value if it is not an HostName" do
        value = stub 'compared', :is_a? => true, :value => "value"
        @value.expects(:eql?).with("value")
        @host.eql?(value)
    end

    it "should delegate hash to the underlying value" do
        @value.expects(:hash)
        @host.hash
    end
end
