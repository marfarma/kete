module ConfigureAsKeteContentItem
  unless included_modules.include? ConfigureAsKeteContentItem
    def self.included(klass)
      # each topic or content item lives in exactly one basket
      klass.send :belongs_to, :basket

      # where we handle creator and contributor tracking
      klass.send :include, HasContributors

      # all our ZOOM_CLASSES need this to be searchable by zebra
      klass.send :include, ConfigureActsAsZoomForKete

      # methods related to handling the xml kept in extended_content column
      klass.send :include, ExtendedContent

      # everything except comments themselves is commentable
      # we also skip related stuff for comments
      unless klass.name == 'Comment'
        # relate to topics
        klass.send :include, RelatedContent

        klass.send :include, KeteCommentable
      end

      # sanitize our descriptions and extended_content for security
      # see validate_as_sanitized_html below, too
      # but allow site admin to override
      klass.send :attr_accessor, :do_not_sanitize
      klass.send :acts_as_sanitized, :fields => [:description]

      # note, since acts_as_taggable doesn't support versioning
      # out of the box
      # we also track each versions raw_tag_list input
      # so we can revert later if necessary
      klass.send :acts_as_taggable

      # we override acts_as_versioned dependent => delete_all
      # because of the complexity our relationships of our models
      # delete_all won't do the right thing (at least not in migrations)
      klass.send :acts_as_versioned, :association_options => { :dependent => :destroy }

      # this is a little tricky
      # the acts_as_taggable declaration for the original
      # is different than how we use tags on the versioned model
      # where we use it for flagging moderator options, like 'flag as inappropriate'
      # where 'inappropriate' is actually a tag on that particular version
      Module.class_eval("#{klass.name}::Version").send(:acts_as_taggable)

      # methods and declarations related to moderation and flagging
      klass.send :include, Flagging

      klass.send :validates_presence_of, :title

      klass.send :validates_as_sanitized_html, [:description, :extended_content]

      # TODO: globalize stuff, uncomment later
      # translates :title, :description
    end

    # turn pretty urls on or off here
    include FriendlyUrls
    alias :to_param :format_for_friendly_urls
  end
end
