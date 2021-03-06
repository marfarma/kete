# lib/tasks/zebra.rake
#
# tasks related to setting up and running zebra for kete
#
# Walter McGinnis, 2007-08-11
#
# $ID: $

desc "Tasks related to running the Zebra search index server for Kete"
namespace :zebra do
  desc "Set the kete user password in the zebradb/keteaccess file"
  task :set_keteaccess do
    `htpasswd -cbp #{RAILS_ROOT}/zebradb/keteaccess kete #{ENV['ZEBRA_PASSWORD']}`
  end

  desc "Set default zebra databases' ports in zebradb/config/kete-zebra-servers.xml based on a template"
  task :set_ports do
    ENV['PUBLIC_PORT']

    conf_file_path = "#{RAILS_ROOT}/zebradb/conf/kete-zebra-servers.xml"

    # read in template
    servers_conf_xml = File.read("#{conf_file_path}.template")

    specs = { 'unix_spec_private' => "unix:#{RAILS_ROOT}/tmp/sockets/zebra-#{ENV['PRIVATE_PORT']}",
      'unix_spec_public' => "unix:#{RAILS_ROOT}/tmp/sockets/zebra-#{ENV['PUBLIC_PORT']}",
      'private_spec' => "tcp:localhost:#{ENV['PRIVATE_PORT']}",
      'public_spec' => "tcp:@:#{ENV['PUBLIC_PORT']}" }

    specs.each do |spec_name, listen_spec|
      servers_conf_xml = servers_conf_xml.gsub(spec_name, listen_spec)
    end

    # write out new file content
    dest = File.new(conf_file_path,'w+')
    dest << servers_conf_xml
    dest.close
  end

  desc "Initialize a specific Zebra server database.  This will erase any existing data.  Be careful."
  task :init do
    # have to run the command from inside #{RAILS_ROOT}/zebradb/database_directory
    db = ENV['ZEBRA_DB'] || 'public'
    `cd #{RAILS_ROOT}/zebradb/#{db}; zebraidx -c ../conf/zebra-#{db}.cfg -d #{db} init`
    `cd #{RAILS_ROOT}/zebradb/#{db}; zebraidx -c ../conf/zebra-#{db}.cfg -d #{db} commit`
  end

  desc "Start the Zebra server instance for this Kete"
  task :start do
    # have to run the command from inside #{RAILS_ROOT}/zebradb
    `cd #{RAILS_ROOT}/zebradb; zebrasrv -f conf/kete-zebra-servers.xml -l #{RAILS_ROOT}/log/zebra.log -p #{RAILS_ROOT}/log/zebra.pid -D`
  end

  desc "Stop the Zebra server instance for this Kete and all its child processes"
  task :stop do
    # have to run the command from inside #{RAILS_ROOT}/zebradb
    pid_file = RAILS_ROOT + '/log/zebra.pid'
    `cd #{RAILS_ROOT}/zebradb; ./zebrasrv-kill.sh #{pid_file}`
  end

  # Added by James Stradling - 2008-05-21
  desc "Insert initial blank records into the public and private zebra instances"
  task :load_initial_records => :environment do
    # Load and render the OAI-PHM record to load
    template = File.read(File.join(RAILS_ROOT, 'zebradb/bootstrap.xml.erb'))
    zoom_record = ERB.new(template).result

    # Save the record into both public and private zoom indexes
    # Assumes that both databases will be local and accessible by public and
    # private respectively
    ["public", "private"].each do |prefix|
      begin
        zoom_db = ZoomDb.find_by_database_name(prefix)
        the_record_id = "#{ZoomDb.zoom_id_stub}bootstrap:Bootstrap:1"
        should_add_record = true
        should_add_record = false if (zoom_db.respond_to?(:has_zoom_record?) && zoom_db.has_zoom_record?(the_record_id)) rescue false

        if should_add_record
          zoom_db.save_this(zoom_record, the_record_id)

          puts " Initial record added to #{prefix} zebra instance (OAI identifier: oai:#{ZoomDb.zoom_id_stub}:bootstrap:Bootstrap:1)."
        else
          puts " Initial record exists, skipping in #{prefix}."
        end
      rescue
        puts " Error while adding record to #{prefix} zebra instance (#{$!})."
      end
    end
  end

  # Walter McGinnis, 2010-06-17
  # use zebra index tool rather than ZOOM External services
  # to add search records
  desc "Zebra index records for this Kete"
  task :index do
    ['public', 'private'].each do |db|
      # have to run the command from inside #{Rails.root}/zebradb/#{db}
      `cd #{Rails.root}/zebradb/#{db}; zebraidx -c ../conf/zebra-#{db}.cfg -l #{Rails.root}/log/zebra.log update data; zebraidx -c ../conf/zebra-#{db}.cfg commit` unless ENV['SKIP_PRIVATE'] && db == 'private'
    end
    puts "Zebra index completed. See #{Rails.root}/log/zebra.log for details."
  end
end
