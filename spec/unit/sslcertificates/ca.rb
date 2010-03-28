#!/usr/bin/env ruby

require File.dirname(__FILE__) + '/../../spec_helper'

require 'puppet/sslcertificates/ca'

describe Puppet::SSLCertificates::CA do
    describe "when storing client CSRs" do

        it "should raise an error if there's already a CSR for the client" do
        end

        it "should write the CSRs pem to a file with the proper name in the csrdir" do
        end
 
        describe ", there is already a signed certificate for the client" do

            describe " and Puppet[:replace_certs] is true" do
                it "should generate a notice" do
                end
                it "should remove the certificate" do
                end
                it "should rebuild the inventory" do
                end
            end

            describe " and Puppet[:replace_certs] is false" do
                it "should generate a warning" do
                end
                it "should not remove the certificate" do
                end
            end

            describe ", Puppet[:replace_certs] is '', " do
                describe " and Puppet[:autosign] is false" do 
                    it "should generate a notice" do
                    end
                    it "should remove the certificate" do
                    end
                    it "should rebuild the inventory" do
                    end
                end
                describe "and Puppet[:autosign] is true" do
                    it "should generate a warning" do
                    end
                    it "should not remove the certificate" do
                    end
                end
                describe "Puppet[:autosign] is a filename, " do
                   describe "and we would not autosign the host" do
                        it "should generate a notice" do
                        end
                        it "should remove the certificate" do
                        end
                        it "should rebuild the inventory" do
                        end
                   end
                   describe "and we would autosign the host" do
                        it "should generate a warning" do
                        end
                        it "should not remove the certificate" do
                        end
                    end
                end
            end
        end
    end
end

