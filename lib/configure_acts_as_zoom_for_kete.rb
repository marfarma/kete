module ConfigureActsAsZoomForKete
  # oai_record is a virtual attribute that holds the topic's entire content
  # as xml formated how we like it
  # for use by acts_as_zoom virtual_field_name, :raw => true
  # this virtual attribue will be populated/updated in our controller
  # in create and update
  # we also opt to explicitly call the zoom_save method ourselves
  # otherwise lots of attributes we need for the oai_record
  # aren't available
  unless included_modules.include? ConfigureActsAsZoomForKete
    attr_accessor :oai_record
    attr_accessor :basket_urlified_name
    def self.included(klass)
      # important that this goes before acts_as_zoom declaration
      klass.send :before_destroy, :prepare_for_zoom_id
      klass.send :private, :prepare_for_zoom_id

      klass.send :acts_as_zoom, :fields => [:oai_record],
                                :save_to_public_zoom => ['localhost', 'public'],
                                :save_to_private_zoom => ['localhost', 'private'],
                                :raw => true,
                                :additional_zoom_id_attribute => :prepare_for_zoom_id,
                                :use_save_callback => false

    end

    def prepare_for_zoom_id
      self.basket_urlified_name = self.basket.urlified_name
    end
  end
end
