module PhobosHelpers

  def phobos_config_path
    File.expand_path(File.join(File.dirname(__FILE__), '../../config/phobos.yml.example'))
  end

end
