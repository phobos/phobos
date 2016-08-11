module Phobos
  module CLI
    class Init
      include Thor::Actions

      def self.source_root
        File.expand_path(File.join(File.dirname(__FILE__), '../../..'))
      end

      def execute
        copy_file 'config/phobos.yml.example', 'config/phobos.yml'
        create_file 'phobos_boot.rb' do
          <<~EXAMPLE
            # Use this file to load your code
            puts "phobos_boot.rb - find this file at \#{File.expand_path(__FILE__)}"
          EXAMPLE
        end
      end
    end
  end
end
