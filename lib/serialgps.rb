#!/usr/bin/ruby

#
# Provides an easy way to get GPS data from your serial GPS unit. 
#
# == Data
# Currently only $GPGGA and $GPRMC NMEA sentences are parsed -- but these have the most
# useful information anyways. For more information on NMEA sentences: http://aprs.gids.nl/nmea/
#
# == Requirements
# * A serial GPS module. (This was tested with the EM-406A SiRF III GPS receiver)
# * serialport ruby gem (http://rubyforge.org/projects/ruby-serialport/)
#
# == Install
# <code>$ gem install ruby-serialport </code>
#
# Author:: Jeremy Gillick (http://blog.mozmonkey.com/)
# License:: Distributes under the same terms as Ruby
#

require 'rubygems'
require 'serialport'
require 'date'

# Connects to the GPS unit and parses the NMEA sentences.
class SerialGPS
	
	# Connect to the serial device.
	def initialize(device, baud=4800, bits=8, stop=1, parity=SerialPort::NONE)
		@serial = SerialPort.new(device, baud, bits, stop, parity)
		@serial.read_timeout = 30 * 1000 # 10 second timeout for reads
		@data = {}
		@collected = []
	end
	
	# Close the serial connection to the GPS unit.
	def close
		@serial.close	
	end

	# Reads NMEA until at least the GGA and RMC data has been loaded
	#
	# last_nmea::  					The last NMEA sentence name (without "$GP") parsed with the read method.
	# quality::							0 = invalid, 1 = GPS fix, 2 = DGPS fix
	# validity::						A = ok, V = invalid
	# latitude::						Latitude
	# lat_ref::							North/South (N/S)
	# longitude::						Longitude
	# long_ref::						East/West (E/W)
	# altitude::						Current altitude
	# alt_unit::						Altitude height unit of measure (i.e. M = Meters)
	# speed::								Speed over ground in knots
	# heading::							Heading, in degrees
	# course::							Course over ground in degrees
	# time::								Current time formated as HHMMSS.SS -- use date_time to get the parsed version
	# date::								Current date formated as DDMMYY -- use date_time to get the parsed version
	# local_hour_offset::		Local zone description, 00 to +/- 13 hours 
	# local_minute_offset::	Local zone minutes description (same sign as hours) 
	# num_sat::							The number of satellites in view
	# satellites::					An array with id, elevation, azimuth and SNR for each satellite
	# height_geoid::				Height of geoid above WGS84 ellipsoid
	# height_geoid_unit::		Unit of measure (i.e. M = Meters)
	# last_dgps::						Time since last DGPS update
	# dgps::								DGPS reference station id
	# mode::								M = Manual (forced to operate in 2D or 3D) A = Automatic (3D/2D)
	# mode_dimension::			1 = Fix not available, 2 = 2D, 3 = 3D
	# hdop::								Horizontal Dilution of Precision
	# pdop::								Positional Dilution of Precision
	# vdop::								Vertical Dilution of Precision
	# msg_count::						Total number of messages of this type in this cycle
	# msg_num::							Message number
	# variation::						Magnetic variation
	# var_direction::				Magnetic variation direction (i.e E = East)
	#
	def get_data
		data = {}

		reads = 0
		errors = 0
		while true do
			
			begin
				read()
			
				# Have we gathered enough data yet
				if @collected.include?("GGA") && @collected.include?("RMC") && reads > 5
					break
				elsif reads > 25
					raise "Could not gather enough data from the GPS. Perhaps the NMEA data is corrupt. Did you specifiy the correct serial device?"
				end
				
				reads += 1
				errors = 0
			rescue
				errors += 1
				if errors > 5
					raise $!
				end
			end
			
		end

		return @data
	end
	
	# Parses the next NMEA sentence from the GPS and returns the current GPS data hash.
	def read
		
		# Parse NMEA sentence until we find one we can use
		while true do
			nmea = next_sentence
			data = parse_NMEA(nmea)
			
			# Sentence parsed, now merge
			unless data[:last_nmea].nil?
				@collected << data[:last_nmea]
				@collected.uniq!
				@data.merge!(nmea)	
				
				break
			end
			
		end

		return @data
	end
	
	# Retuns the next raw NMEA sentence string
	def next_sentence
	
		# Loop through serial data
		buffer = ""
		while true do
			c = @serial.getc
			if c.nil?
				raise "Can't connection to the GPS!"
			end

			# End of the line, collect the data
			if c == 10
				buffer.lstrip!
				
				# Valid sentence
				if buffer[0,1] == "$"
					break
					
				# Try again, probably a partial line
				else
					buffer = ""
				end
				
			# Add to buffer
			else
				buffer << c
			end
		end
		
		buffer
	end
	
	# Prints the live GPS data to the console.
	def live_gps_dump
		puts "Reading...\n"
		buffer = ""
		data = {}
		rows = 1
		errors = 0

		while true do
			begin
				read
	
				# Clear previous data
				if rows > 0
					$stdout.print "\e[#{rows}A\e[E\e[J"
					rows = 0
				end
				errors = 0
				
				# Get date		
				if data.key?(:time) && data.key?(:date)
					date = self.date_time 
					if date.nil?
	          date = ""
	  		  else
	    		  date = date.strftime("%b %d %I:%M %p")
	  		  end
				else
					output = false
					next
				end
	
				$stdout.print "Time: #{date}	Satellites: #{data[:num_sat]}		Quality:#{data[:quality]}\n"
				$stdout.print "Latitude: #{data[:latitude]}#{data[:lat_ref]}"
				$stdout.print "\tLongitude: #{data[:longitude]}#{data[:long_ref]}"
				$stdout.print "\tElevation: #{data[:altitude]}#{data[:alt_unit]}\n"
				rows += 3
				
				# Satellites
				$stdout.print "-- Satellites --\n"
				data[:num_sat].times do | i | 
					
					if data[:num_sat][:satellites].size > i
						sat = data[:num_sat][:satellites][i]
						rows += 1
						
						$stdout.print "#{sat[:id]}: "
						$stdout.print "Elevation: #{sat[:elevation]}"
						$stdout.print "\tAzimuth: #{sat[:azimuth]}\n"
					end
				end
				rows += 1
			
			rescue
				# Clear previous error
				if errors > 0
					$stdout.print "\e[1A\e[E\e[J"
					errors = 0
				end
			
				$stdout.print "#{$!}"
				rows += 1
				errors += 1	
			end
			
			$stdout.flush
		end
	end 

	# Returns a DateTime object representing the date and time provided by the GPS unit or NIL if this data is not available yet.
	def date_time()
		if !@data.key?(:time) || @data[:time].empty? || !@data.key?(:date) || @data[:date].empty?
			return nil
		end

		time = @data[:time]
		date = @data[:date]
		time.gsub!(/\.[0-9]*$/, "") # remove decimals
		datetime = "#{date} #{time} UTC"
		puts datetime
		date =  DateTime.strptime(datetime, "%d%m%y %H%M%S %Z")
		date
	end
	
	# Parse a raw NMEA sentence and respond with the data in a hash
	def parse_NMEA(raw)
		data = { :last_nmea => nil }
		if raw.nil?
			return data
		end
		raw.gsub!(/[\n\r]/, "")

		line = raw.split(",");
		if line.size < 1
			return data
		end
		
		# Invalid sentence, does not begin with '$'
		if line[0][0, 1] != "$"
			return data
		end
		
		# Parse sentence
		type = line[0][3, 3]
		line.shift

		if type.nil?
			return data
		end
		
		case type
			when "GGA"
				data[:last_nmea] = type
				data[:time]					= line.shift
				data[:latitude]			= line.shift
				data[:lat_ref]			= line.shift
				data[:longitude]		= line.shift
				data[:long_ref]			= line.shift
				data[:quality]			= line.shift
				data[:num_sat]			= line.shift.to_i
				data[:hdop]					= line.shift
				data[:altitude]			= line.shift
				data[:alt_unit]			= line.shift
				data[:height_geoid]	= line.shift
				data[:height_geoid_unit] = line.shift
				data[:last_dgps]		= line.shift
				data[:dgps]					= line.shift
	
			when "RMC"
				data[:last_nmea] = type
				data[:time]				= line.shift
				data[:validity]		= line.shift
				data[:latitude]		= line.shift
				data[:lat_ref]		= line.shift
				data[:longitude]	= line.shift
				data[:long_ref]		= line.shift
				data[:speed]			= line.shift
				data[:course]			= line.shift
				data[:date]				= line.shift
				data[:variation]	= line.shift
				data[:var_direction]	= line.shift
				
			when "GLL"
				data[:last_nmea] 	= type
				data[:latitude]		= line.shift
				data[:lat_ref]		= line.shift
				data[:longitude]	= line.shift
				data[:long_ref]		= line.shift
		  	data[:time]				= line.shift
				
			when "RMA"
				data[:last_nmea] = type
				line.shift # data status
				data[:latitude]		= line.shift
				data[:lat_ref]		= line.shift
				data[:longitude]	= line.shift
				data[:long_ref]		= line.shift
		  	line.shift # not used
		  	line.shift # not used
				data[:speed]			= line.shift
				data[:course]			= line.shift
				data[:variation]	= line.shift
				data[:var_direction]	= line.shift
		  	
			when "GSA"
				data[:last_nmea] = type
				data[:mode]						= line.shift
				data[:mode_dimension]	= line.shift
		  	
		  	# Satellite data
		  	data[:satellites] ||= []
		  	12.times do |i|
		  		id = line.shift
		  		
		  		# No satallite ID, clear data for this index
		  		if id.empty?
		  			data[:satellites][i] = {}
		  		
		  		# Add satallite ID
		  		else
			  		data[:satellites][i] ||= {}
			  		data[:satellites][i][:id] = id
		  		end
		  	end
		  	
		  	data[:pdop]			= line.shift
		  	data[:hdop]			= line.shift
		  	data[:vdop]			= line.shift
		  	
			when "GSV"
				data[:last_nmea] = type
				data[:msg_count]	= line.shift
				data[:msg_num]		= line.shift
				data[:num_sat]		= line.shift.to_i
				
				# Satellite data
		  	data[:satellites] ||= []
		  	4.times do |i|
		  		data[:satellites][i] ||= {}
		  		
					data[:satellites][i][:elevation]	= line.shift
			  	data[:satellites][i][:azimuth]		= line.shift
			  	data[:satellites][i][:snr]				= line.shift
		  	end
		  	
		  when "HDT"
				data[:last_nmea] = type
				data[:heading]	= line.shift
				
			when "ZDA"
				data[:last_nmea] = type
				data[:time]	= line.shift
				
				day		= line.shift
				month	= line.shift
				year	= line.shift
				if year.size > 2
					year = [2, 2]
				end
				data[:date] = "#{day}#{month}#{year}"
				
				data[:local_hour_offset]		= line.shift
				data[:local_minute_offset]	= line.shift
		end
		
		# Remove empty data
		data.each_pair do |key, value|
			if value.nil? || (value.is_a?(String) && value.empty?)
				data.delete(key)
			end
		end
		
		data
	end
end
