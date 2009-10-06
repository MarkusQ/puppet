require File.dirname(__FILE__) + '/../../spec_helper'

describe "generating resources" do
	before do
		@resource = Puppet::Type.type(:host).new(:name => 'localhost', :ip => '127.0.0.1')
        @catalog = Puppet::Resource::Catalog.new
		@context = Puppet::Transaction.new(@catalog)
		resource_type = mock("Resource type", :instances => [@resource])
		@resource.stubs(:resource_type).returns(resource_type)
		@resource.stubs(:purge?).returns(true)
	end

	describe "when the catalog contains a resource" do
		before do
			@catalog.add_resource @resource
		end

		it "should not generate a duplicate of that resource" do
			lambda do
				@context.generate_additional_resources(@resource, :generate)
			end.should_not raise_error
		end
	end
end
