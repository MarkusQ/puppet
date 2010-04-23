require 'puppet/ssl/base'

# Manage certificates themselves.  This class has no
# 'generate' method because the CA is responsible
# for turning CSRs into certificates; we can only
# retrieve them from the CA (or not, as is often
# the case).
class Puppet::SSL::Certificate < Puppet::SSL::Base
    # This is defined from the base class
    wraps OpenSSL::X509::Certificate

    extend Puppet::Indirector
    indirects :certificate, :terminus_class => :file

    class InvalidCertificate < Puppet::Error; end

    # Convert a string into an instance.
    def self.from_s(string)
        instance = wrapped_class.new(string)
        name = instance.subject.to_s.sub(/\/CN=/i, '').downcase
        result = new(name)
        result.content = instance
        result
    end

    # Because of how the format handler class is included, this
    # can't be in the base class.
    def self.supported_formats
        [:s]
    end

    def expiration
        # Our expiration is either that of the cache or the content, whichever comes first
        cache_expiration = @expiration
        [(content and content.not_after), cache_expiration].compact.sort.first
    end

    def self.hostcert
        file = Puppet[:hostcert]
        unless ::File.exists?(file)
            dir = ::File.dirname(file)
            short = ::File.basename(file)
            raise ArgumentError, "Tried to fix SSL files to a file containing uppercase" unless short.downcase == short
            real_files = ::File.directory?(dir) ? Dir.entries(dir).select { |f| f !~ /^\./ and f.downcase == short } : []
            case real_files.length
            when 0 #nothing to do
            when 1
                file_found = ::File.join(dir, real_files.first)
                Puppet.notice "Fixing case in #{file_found}; renaming to #{file}"
                File.rename(file_found, file)
            else
                Puppet.notice "Multiple files match #{file}: #{real_files.join(', ')}"
            end
        end
        OpenSSL::X509::Certificate.new(::File.read(file)) if ::File.exists?(file)
    rescue => detail
        raise InvalidCertificate, "Could not read hostcert in #{file}: #{detail}"
    end
end
