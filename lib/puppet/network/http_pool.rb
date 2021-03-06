require 'puppet/ssl/host'
require 'net/https'
require 'puppet/util/cacher'

module Puppet::Network; end

# Manage Net::HTTP instances for keep-alive.
module Puppet::Network::HttpPool
  class << self
    include Puppet::Util::Cacher

    private

    cached_attr(:http_cache) { Hash.new }
  end

  # Use the global localhost instance.
  def self.ssl_host
    Puppet::SSL::Host.localhost
  end

  # 2008/03/23
  # LAK:WARNING: Enabling this has a high propability of
  # causing corrupt files and who knows what else.  See #1010.
  HTTP_KEEP_ALIVE = false

  def self.keep_alive?
    HTTP_KEEP_ALIVE
  end

  # Clear our http cache, closing all connections.
  def self.clear_http_instances
    http_cache.each do |name, connection|
      connection.finish if connection.started?
    end
    Puppet::Util::Cacher.expire
  end

  # Make sure we set the driver up when we read the cert in.
  def self.read_cert
    if val = super # This calls read_cert from the Puppet::SSLCertificates::Support module.
      # Clear out all of our connections, since they previously had no cert and now they
      # should have them.
      clear_http_instances
      return val
    else
      return false
    end
  end

  # Use cert information from a Puppet client to set up the http object.
  def self.cert_setup(http)
    # Just no-op if we don't have certs.
    return false unless FileTest.exist?(Puppet[:hostcert]) and FileTest.exist?(Puppet[:localcacert])

    http.cert_store = ssl_host.ssl_store
    http.ca_file = Puppet[:localcacert]
    http.cert = ssl_host.certificate.content
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    http.key = ssl_host.key.content
    http.verify_callback = self.method(:ssl_verify_callback).to_proc if Puppet[:debug]
  end

  def self.ssl_verify_callback(peer_ok, x509_store_ctx)
    if not peer_ok
      Puppet.debug "OpenSSL: Error(#{x509_store_ctx.error}): #{x509_store_ctx.error_string}"
      Puppet.debug "OpenSSL: Cert: #{x509_store_ctx.current_cert.issuer}"
      Puppet.debug "OpenSSL: Current CRL: #{x509_store_ctx.current_crl}"
      Puppet.debug "OpenSSL: Chain:"
      x509_store_ctx.chain.each_index { |i| Puppet.debug "OpenSSL: \t#{i} #{x509_store_ctx.chain[i].issuer}" }
    end
    peer_ok
  end

  # Retrieve a cached http instance if caching is enabled, else return
  # a new one.
  def self.http_instance(host, port, reset = false)
    # We overwrite the uninitialized @http here with a cached one.
    key = "#{host}:#{port}"

    # Return our cached instance if we've got a cache, as long as we're not
    # resetting the instance.
    if keep_alive?
      return http_cache[key] if ! reset and http_cache[key]

      # Clean up old connections if we have them.
      if http = http_cache[key]
        http_cache.delete(key)
        http.finish if http.started?
      end
    end

    args = [host, port]
    if Puppet[:http_proxy_host] == "none"
      args << nil << nil
    else
      args << Puppet[:http_proxy_host] << Puppet[:http_proxy_port]
    end
    http = Net::HTTP.new(*args)

    # Pop open the http client a little; older versions of Net::HTTP(s) didn't
    # give us a reader for ca_file... Grr...
    class << http; attr_accessor :ca_file; end

    http.use_ssl = true
    # Use configured timeout (#1176)
    http.read_timeout = Puppet[:configtimeout]
    http.open_timeout = Puppet[:configtimeout]

    cert_setup(http)

    http_cache[key] = http if keep_alive?

    http
  end
end
