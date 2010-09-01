require 'puppet/file_serving/mount'

# Find files in the modules' plugins directories.
# This is a very strange mount because it merges
# many directories into one.
class Puppet::FileServing::Mount::Plugins < Puppet::FileServing::Mount
  # Return an instance of the appropriate class.
  def find(relative_path, request)
    p [:find,request.environment]
    return nil unless mod = request.environment.modules.find { |mod|  mod.plugin(relative_path) }

    path = mod.plugin(relative_path)

    path
  end

  def search(relative_path, request)
    # We currently only support one kind of search on plugins - return
    # them all.
    p [:search,request.environment]
    paths = request.environment.modules.find_all { |mod| p [mod.class,mod.respond_to?(:plugins?),mod.path]; mod.plugins? }.collect { |mod| mod.plugin_directory }
    p paths
    return(paths.empty? ? nil : paths)
  end

  def valid?
    true
  end
end
