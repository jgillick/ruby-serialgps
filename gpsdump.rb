#!/usr/bin/ruby

# Simple command line script that prints live GPS data to the console.
# 
# == Usage
# From the command line, call the script with the GPS serial device as the only
# argument:
#
# <code>$ gpsdump.rb /dev/ttyUSB0</code>
#
# == Example Output
#
#   Time: Apr 20 11:44 AM 	Satellites: 05		Quality:1
#   Latitude: 4124.8963N	Longitude: 08151.6838W	Elevation: 35.7M
#

require "lib/serialgps"

if ARGV.size < 1
	puts "USAGE gpsdump.rb <Serial Device>\n"
	puts "Example: gpsdump.rb /dev/ttyUSB0\n"
	exit 0
end

device = ARGV[0]
gps = SerialGPS.new(device)
gps.live_gps_dump
