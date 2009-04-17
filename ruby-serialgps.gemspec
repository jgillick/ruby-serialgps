Gem::Specification.new do |s|
   s.name = "ruby-serialgps"
   s.version = "0.0.1"
   s.date = %q{2009-04-20}
   s.authors = ["Jeremy Gillick"]
   s.email = "none@sorry.com"
   s.summary = "Get data from your serial GPS with Ruby."
   s.homepage = "http://blog.mozmonkey.com"
   s.description = "Read NMEA data from standard serial GPS modules and provides the data as a hash."
   
   s.has_rdoc = true
   s.files = [ "gpsdump.rb", "lib/serialgps.rb", "README.rdoc" ]
   s.add_dependency("serialport", ">= 0.7.0")
   
end 
