require 'openssl'
require 'puppet'
require 'puppet/ssl'
require 'xmlrpc/server'

# Much of this was taken from QuickCert:
#   http://segment7.net/projects/ruby/QuickCert/

class Puppet::Network::Handler::CA < Puppet::Network::Handler
    desc "Provides an interface for signing CSRs.  Accepts a CSR and returns
    the CA certificate and the signed certificate, or returns nil if
    the cert is not signed."

    @interface = XMLRPC::Service::Interface.new("puppetca") { |iface|
        iface.add_method("array getcert(csr)")
    }

    def initialize(hash = {})
        Puppet.settings.use(:main, :ssl, :ca)
    end

    # our client sends us a csr, and we either store it for later signing,
    # or we sign it right away
    def getcert(csrtext, client = nil, clientip = nil)
        # Use the hostname from the CSR, not from the network.
        csr = OpenSSL::X509::Request.new(csrtext)
        subject = csr.subject

        nameary = subject.to_a.find { |ary|
            ary[0] == "CN"
        }

        if nameary.nil?
            Puppet.err(
                "Invalid certificate request: could not retrieve server name"
            )
            return "invalid"
        end

        hostname = nameary[1]

        request = Puppet::SSL::CertificateRequest.new(hostname)
        request.content = csr
        request.save

        if cert = Puppet::SSL::Certificate.find(hostname)
            return cert.content.to_s
        else
            return ""
        end
    end
end
