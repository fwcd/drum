require 'webrick'

module Drum
  def self.run_server(db, options)
    port = options[:port]&.to_i || 8008
    server = WEBrick::HTTPServer.new :Port => port

    # TODO: Use erb for templating
    server.mount_proc '/' do |req, res|
      lists = db[:playlists]
        .select_map(:name)
        .map { |name| "<li>#{name}</li>" }
        .join("\n")

      res.content_type = 'text/html'
      res.body = [
        '<!DOCTYPE html>',
        '<html>',
        '  <head>',
        '    <meta charset="utf-8" />',
        '    <title>Drum Library</title>',
        '  </head>',
        '  <body>',
        '    <h1>Drum Library</h1>',
        '    <ul>',
        lists,
        '    </ul>',
        '  </body>',
        '</html>'
      ].join("\n")
    end

    trap 'INT' do server.shutdown end
    server.start
  end
end
