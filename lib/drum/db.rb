require 'sequel'

module Drum
  def self.setup_db(uri)
    # db = Sequel.connect(uri)
    db = Sequel.sqlite
    
    db.create_table?(:playlists) do
      # TODO
    end

    return db
  end
end
