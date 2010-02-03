require 'yaml'
require 'sync'

require 'puppet/util/file_locking'

# a class for storing state
class Puppet::Util::Storage
    include Singleton
    include Puppet::Util

    def initialize
        self.class.load
    end

    def self.cache_key_for(object)
        case object
            when Puppet::Type; object.ref
            when Symbol;       object
            else raise ArgumentError, "You can only cache information for Types and symbols"
            end
    end

    # Return a hash that will be stored to disk.  
    def self.cache(object)
        @@state[cache_key_for(object)]
    end

    def self.forget(object)
        @@state.delete(cache_key_for(object))
    end

    def self.clear
        @@state = Hash.new { |h,k| h[k] = @@prior_state[k] || {} }
        @@prior_state = {}
    end

    clear

    def self.load
        Puppet.settings.use(:main) unless FileTest.directory?(Puppet[:statedir])

        return unless File.exists?(Puppet[:statefile])
        Puppet::Util.benchmark(:debug, "Loaded state") do
            Puppet::Util::FileLocking.readlock(Puppet[:statefile]) do |file|
                begin
                    @@prior_state = YAML.load(file)
                    puts "Loaded #{@@prior_state.inspect}"
                rescue => detail
                    Puppet.err "Checksumfile %s is corrupt (%s); replacing" %
                        [Puppet[:statefile], detail]
                    begin
                        File.rename(Puppet[:statefile],
                            Puppet[:statefile] + ".bad")
                    rescue
                        raise Puppet::Error,
                            "Could not rename corrupt %s; remove manually" %
                            Puppet[:statefile]
                    end
                end
            end
        end

        unless @@prior_state.is_a?(Hash)
            Puppet.err "State got corrupted"
            clear
        end

        #Puppet.debug "Loaded state is %s" % @@state.inspect
    end

    def self.stateinspect
        @@state.inspect
    end

    def self.priorstateinspect
        @@prior_state.inspect
    end

    def self.store
        Puppet.debug "Storing state"

        unless FileTest.exist?(Puppet[:statefile])
            Puppet.info "Creating state file %s" % Puppet[:statefile]
        end

        Puppet::Util.benchmark(:debug, "Stored state") do
            Puppet::Util::FileLocking.writelock(Puppet[:statefile], 0660) do |file|
                file.print YAML.dump(@@state)
            end
        end
    end
end
