require "json"
require "tempfile"
require "yaml"
require "securerandom"

module ECSUtil
  module Helpers
    def step_info(message, *params)
      message = sprintf(message, *params) if params.any?
      puts "----> #{message}"
    end

    def confirm(title = nil, required = "Y")
      title ||= "Are you sure?"
      print "#{title} (Y/N): "
      
      if STDIN.gets.strip != required
        puts "Aborted"
        exit 1
      end
    end

    def terminate(message)
      puts message
      exit 1
    end

    def json_file(data)
      f = Tempfile.new
      f.write(JSON.pretty_generate(data))
      f.flush
      f.path
    end

    def array_hash(data = {}, key_name = :key, value_name = :value)
      data.to_a.map do |k,v|
        {
          key_name.to_sym => k,
          value_name.to_sym => v
        }
      end
    end 
    
    def parse_env_data(data)
      data.
        split("\n").
        map(&:strip).
        reject { |l| l.start_with?("#") || l.empty? }.
        map { |l| l.split("=", 2) }.
        to_h
    end
  end
end