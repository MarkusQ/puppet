#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../spec_helper'

describe Puppet::Util do

    describe "execute" do
        it "should be a module method of Puppet::Util" do
            Puppet::Util.should respond_to(:execute)
        end

        #     def execute(command, arguments = {:failonfail => true, :combine => true})
        
        it "should insist that the command be an array" do
            lambda { Puppet::Util.execute('test') }.should raise_error(ArgumentError)
        end

        [false,nil,'not given'].each { |squelch|
            describe "when squelch is #{squelch||squelch.inspect}" do
                before :each do
                    @args = {}
                    @args[:squelch] = squelch unless squelch == 'not given'
                end
                it "should execute its command and return the results" do
                    Puppet::Util.execute(['echo','mydata'],@args).should == "mydata\n"
                end
                it "should be able to handle large amounts (>4kb) of output" do
                    # Ticket #2997
                    Puppet::Util.execute(['cat',__FILE__],@args).should == File.read(__FILE__) 
                end
                describe "and failonfail is false" do
                    it "should capture the error message on failure" do
                        # Ticket #2731, comment #11
                        Puppet::Util.execute(["does_not_exist"],@args.update( :failonfail => false) ).should == "No such file or directory - does_not_exist\n"
                    end
                end
                describe "and failonfail is true" do
                    it "should capture the error message on failure" do
                        lambda {Puppet::Util.execute(["does_not_exist"],@args.update( :failonfail => true) )}.should raise_error
                    end
                end
            end
        }
        [true,'some non-nil value'].each { |squelch|
            describe "when squelch is #{squelch}" do
                it "should execute its command" do
                    f = Tempfile.new('execute_test')
                    Puppet::Util.execute(['rm',f.path],:squelch => squelch)
                    File.exists?(f.path).should == false
                end
                it "should ignore the results" do
                    Puppet::Util.execute(['echo','mydata'],:squelch => squelch).should be_nil
                end
                it "should be able to ignore large amounts (>4kb) of output" do
                    # Counterpart to ticket #2997
                    Puppet::Util.execute(['cat',__FILE__],:squelch => squelch).should be_nil 
                end
                describe "and failonfail is false" do
                    it "should not capture the error message on failure" do
                        Puppet::Util.execute(["does_not_exist"],:squelch => squelch, :failonfail => false).should be_nil
                    end
                end
                describe "and failonfail is true" do
                    it "should not capture the error message on failure" do
                        lambda {Puppet::Util.execute(["does_not_exist"],:squelch => squelch, :failonfail => true)}.should raise_error
                    end
                end
            end
        }
        [(:available if $stdin.respond_to? :readpartial),:unavailable].compact.each { |readpartial|
            #
            # Available/unavailable dichotomy motivated by Ticket #3013
            #     Note that we can test how it would work on an old ruby
            #     when we're on a modern one but not the other way around.
            #
            before :each do
                a,b = IO.pipe
                if readpartial == :unavailable and a.respond_to? :readpartial
                    #
                    # We are on a modern ruby but want a to look like
                    # a pipe from 1.8.1/1.8.2 for this test
                    #
                    def a.respond_to?(x)
                        (x.to_sym != :readpartial) and super
                    end
                    def a.readpartial(*args)
                        method_missing(:readpartial,*args)
                    end
                end
                IO.stubs(:pipe).returns([a,b])
            end
            describe "when readpartial is #{readpartial}" do
                it "should be resilient to asynchronous signals" do
                    n = 200
                    begin
                        usr1_count = 0
                        old_usr1_trap = trap(:USR1) { usr1_count += 1 }
                        #
                        # Three components of resiliency are tested together here rather 
                        #     than in three separate it-blocks because the test is slow
                        #     and combining them makes better use of our testing-time
                        #     budget.
                        #
                        task = [File.dirname(__FILE__)+'/exec_test_helper','--kill-me-with','USR1','--called-by',$PID,'--repeat',n]
                        Puppet::Util.execute(task).should == "#{$PID}\n"*n
                        usr1_count.should <= n      # We don't expect phantom signals
                        usr1_count.should >= n-n/4  # We expect 75% or better signal delivery
                    ensure
                        trap(:USR1,old_usr1_trap)
                    end
                end
                it "should not miss output if the other end doles it out bit at a time" do
                    n = 5
                    task = [File.dirname(__FILE__)+'/exec_test_helper','--called-by',$PID,'--repeat',n,'--flush','--delay-each',1.5]
                    Puppet::Util.execute(task).should == "#{$PID}\n"*n
                end
                it "should not mind (hang, crash, lose output) if the other end closes the pipe before completing" do
                    n = 5
                    task = [File.dirname(__FILE__)+'/exec_test_helper','--called-by',$PID,'--repeat',n,'--delay-exit',5]
                    timeout(10) { Puppet::Util.execute(task).should == "#{$PID}\n"*n }
                end
                it "should not hang if the child process terminates but does not close the pipe" do
                    # Ticket #1563 comment #7
                    n = 5
                    task = [File.dirname(__FILE__)+'/exec_test_helper','--called-by',$PID,'--fork-badly','--repeat',n,'--delay-close',50]
                    timeout(20) {  Puppet::Util.execute(task).should == "#{$PID}\n"*n }
                end
                describe "when the child process passes the pipe to a grandchild and terminates without closing the pipe or waiting for the grandchild" do
                    it "should not cause the grandchild child process to receive a SIGPIPE if the grandchild subsequently ignores the pipe" do
                        # Ticket #1563 comment #7, null hypothesis for Ticket #3013 comment #18
                        n = 5
                        task = [File.dirname(__FILE__)+'/exec_test_helper','--called-by',$PID,'--fork-badly','--repeat',n,'--delay-close',30,'--signal-exit']
                        # Note that the trapping setup/teardown appaently can NOT be done in a before block
                        signal = nil
                        old_usr1_trap = trap(:USR1) { signal = :USR1 } # They exited normally
                        old_usr2_trap = trap(:USR2) { signal = :USR2 } # They died
                        old_pipe_trap = trap(:PIPE) { signal = :PIPE } # They got a SIGPIPE
                        timeout(50) {  
                            Puppet::Util.execute(task).should == "#{$PID}\n"*n
                            `sleep 0` until signal # Process sleep, not thread sleep
                        }
                        trap(:USR1,old_usr1_trap)
                        trap(:USR2,old_usr2_trap)
                        trap(:PIPE,old_pipe_trap)
                        signal.should == :USR1
                    end
                    it "should not cause the grandchild child process to receive a SIGPIPE if the grandchild subsequently writes to the pipe" do
                        # Ticket #3013 comment #18
                        pending %q{
                            This situation is presently only a speculation and may in any case exceed 
                            what we should expect the code to do; see note in the implementation for a 
                            suggested way to handle it if needed.
                        }
                        n = 5
                        task = [File.dirname(__FILE__)+'/exec_test_helper','--called-by',$PID,'--fork-badly','--repeat',n,'--delay-close',30,'--write-in-fork','--signal-exit']
                        # Note that the trapping setup/teardown apparently can NOT be done in a before block
                        signal = nil
                        old_usr1_trap = trap(:USR1) { signal = :USR1 } # They exited normally
                        old_usr2_trap = trap(:USR2) { signal = :USR2 } # They died
                        old_pipe_trap = trap(:PIPE) { signal = :PIPE } # They got a SIGPIPE
                        timeout(50) {  
                            Puppet::Util.execute(task).should == "#{$PID}\n"*n
                            `sleep 0` until signal # Process sleep, not thread sleep
                        }
                        trap(:USR1,old_usr1_trap)
                        trap(:USR2,old_usr2_trap)
                        trap(:PIPE,old_pipe_trap)
                        signal.should == :USR1
                   end
                   it "should be able to deal with the command-line 'pseudo-daemon&' idiom (but not retain the output)" do
                       Puppet::Util.execute(['/bin/sh','-c','(sleep 5; echo foo)&']).should == ''
                   end
                end
            end
        }    
    end
end
