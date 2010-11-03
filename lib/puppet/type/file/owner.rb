module Puppet
  Puppet::Type.type(:file).newproperty(:owner) do

    desc "To whom the file should belong.  Argument can be user name or
      user ID."
    @event = :file_changed

    def insync?(current)
      provider.insync?(current, @should)
    end

    # We want to print names, not numbers
    def is_to_s(currentvalue)
      provider.id2name(currentvalue) || currentvalue
    end

    def should_to_s(newvalue = @should)
      case newvalue
      when Symbol
        newvalue.to_s
      when Integer
        provider.id2name(newvalue) || newvalue
      when String
        newvalue
      else
        raise Puppet::DevError, "Invalid uid type #{newvalue.class}(#{newvalue})"
      end
    end

    def retrieve
      if should
        @should = @should.collect do |val|
          if val.is_a? String
            provider.validuser?(val) || raise "Could not find user #{val}"
          else
            val
          end
        end
      end
      provider.retrieve(@resource)
    end

    def sync
      provider.sync(resource[:path], resource[:links], @should)
    end
  end
end

