module Drum
  class AppleMusicService < Service
    NAME = 'Apple Music'

    def initialize(db)
      @db = db
      service = db[:services].where(:name => NAME).first
      if service.nil?
        @service_id = db[:services].insert(:name => NAME)
      else
        @service_id = service[:id]
      end
    end

    def preview
      # TODO
    end
  end
end
