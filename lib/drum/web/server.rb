require 'webrick'

module Drum
  def self.run_web_server(db, options)
    port = options[:port]&.to_i || 8008
    root = File.expand_path "#{__dir__}/../../../public"

    server = WEBrick::HTTPServer.new Port: port, DocumentRoot: root

    # Slightly hacky approach to inject the database
    # TODO: Add an API and use it instead
    WEBrick::HTTPServlet::ERBHandler.const_set('DB', db)

    trap 'INT' do server.shutdown end
    server.start
  end
end
