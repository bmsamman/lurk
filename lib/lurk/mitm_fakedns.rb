##
# $Id: fakedns.rb 5540 2008-06-25 23:04:19Z hdm $
##

##
# This file is part of the Metasploit Framework and may be subject to 
# redistribution and commercial restrictions. Please see the Metasploit
# Framework web site for more information on licensing and terms of use.
# http://metasploit.com/projects/Framework/
##

require 'resolv'
require 'singleton'
module Lurk
  class FakeDNS
    include Singleton

    def setup config
      Signal.trap("HUP") { puts "Lurk wants out."; stop; exit }
      @real_dns = config[:real_dns]
      @host = config[:host]
      @port = config[:port]
      @mapping_file = config[:mapping_file]
      begin
        fp = File.new(@mapping_file)
      rescue
        puts "Could not open #{@mapping_file} for reading.  Quitting."
        return
      end
      mod_entries = []
      while !fp.eof?
        entry = fp.gets().chomp().split(',')
        mod_entries.push([entry[0],Regexp.new(entry[1])])
      end

      # MacOS X workaround
      #::Socket.do_not_reverse_lookup = true

      @sock = ::UDPSocket.new()
      @sock.setsockopt(::Socket::SOL_SOCKET, ::Socket::SO_REUSEADDR, 1)
      @sock.bind(config[:host], @port)
      @run = true
    end
    
    def stop
      lurk_execute "pkill lurk_dns"
    end
    
    def run config=nil
      exit if @running
      setup(config) if config
      start config
    end
    
    def start config
        begin

          while @run
            @running = true
            packet, addr = @sock.recvfrom(65535)
            if (packet.length == 0)
                break
            end

            request = Resolv::DNS::Message.decode(packet)

            # W: Go ahead and send it to the real DNS server and
            #    get the response
            sock2 = ::UDPSocket.new()
            sock2.send(packet, 0, @real_dns, 53)
            packet2, addr2 = sock2.recvfrom(65535)
            sock2.close()


            real_response = Resolv::DNS::Message.decode(packet2)
            fake_response = Resolv::DNS::Message.new()
            fake_response.qr = 1 # Recursion desired
            fake_response.ra = 1 # Recursion available
            fake_response.id = real_response.id
            real_response.each_question { |name, typeclass|
              fake_response.add_question(name, typeclass)
            }

            real_response.each_answer { |name, ttl, data| 
              replaced = false
              mod_entries.each { |e|
                if name.to_s =~ e[1]
                  case data.to_s 
                  when /IN::A/
                    data = Resolv::DNS::Resource::IN::A.new(e[0])
                    replaced = true
                  when /IN::MX/
                    data = Resolv::DNS::Resource::IN::MX.new(10,Resolv::DNS::Name.create(e[0]))
                    replaced = true
                  when /IN::NS/
                    data = Resolv::DNS::Resource::IN::NS.new(Resolv::DNS::Name.create(e[0]))
                    replaced = true
                  when /IN::PTR/
                    # Do nothing
                    replaced = true
                  else
                    # Do nothing
                    replaced = true
                  end
                end
                break if replaced
              }
              fake_response.add_answer(name,ttl,data)
            }
            real_response.each_authority { |name, ttl, data|
              mod_entries.each { |e|
                if name.to_s =~ e[1] 
                  data = Resolv::DNS::Resource::IN::NS.new(Resolv::DNS::Name.create(e[0]))
      	    break
                end
              }
              fake_response.add_authority(name,ttl,data)
            }
            response_packet = fake_response.encode()
            @sock.send(response_packet, 0, addr[3], addr[1])
          end

      # Make sure the socket gets closed on exit
        rescue ::Exception => e
      	  puts("fakedns: #{e.class} #{e} #{e.backtrace}")
        ensure
      	  @sock.close
        end
    end
  end
end
