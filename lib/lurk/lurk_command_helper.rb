module LurkCommandHelper  
  def run_lurk
    copy_config_if_needed
    opts = lurk_opts
    config = Hash.new
    YAML.load_file('config/lurk.yml').each_pair do |key,value| 
      config[key.to_sym] = value
    end
    if opts[:kill_all]
      Lurk::Lurker.instance.stop
    else
      Lurk::Lurker.instance.run opts.merge(config) 
    end
  end
  
  def run_lurk_dns
    copy_config_if_needed
    opts = lurk_dns_opts
    config = Hash.new
    YAML.load_file('config/lurk_dns.yml').each_pair do |key,value| 
      config[key.to_sym] = value
    end
    
    if opts[:kill_all]
      Lurk::FakeDNS.instance.stop
    else
      Lurk::FakeDNS.instance.run opts.merge(config)
    end
  end
  
  def lurk_opts
    p = Trollop::Parser.new do
      opt :dry_run, "Don't actually do anything, just print steps", :short => "-d"
      opt :log_dir, "Output logs to this directory", :short => '-l', :type => :string
      opt :iface, "Interface to internet.", :short => '-i', :type => :string
      opt :wiface, "Interface to wireless network.", :short => '-w', :type => :string
      opt :essid, "ESSID to broadcase", :short => '-e', :type => :string
      opt :gateway_ip, "Gateway IP", :short => '-g', :type => :string
      opt :respond_to_all, "Respond to all beacons", :short => '-b'
      opt :kill_all, "Kill all processes", :short => '-k'
      opt :run, "Run with defaults", :short => '-r'
      opt :interactive, "Run in interactive mode", :short => '-a'
    end
    Trollop::with_standard_exception_handling p do
      raise Trollop::HelpNeeded if ARGV.empty? # show help screen
      p.parse
    end
  end
  
  def lurk_dns_opts
    Trollop::options do
      opt :real_dns, "Real DNS", :short => '-d', :type => :string
      opt :host, "Fake DNS Host", :short => '-e', :type => :string
      opt :port, "Fake DNS Port", :short => '-p', :type => :int
      opt :mapping_file, "Path to dns mapping file", :short => '-m', :type => :string
    end
  end
  
  def copy_config_if_needed
    Dir.mkdir 'config' unless File.exists? 'config'
    config_origin_path = File.expand_path(File.join(File.dirname(__FILE__), '..','..','config'))
    %w{lurk.yml lurk_dns.yml mapping.txt}.each do |file|
      FileUtils.cp File.join(config_origin_path, file), "config/#{file}" unless File.exists? "config/#{file}"
    end
  end
end