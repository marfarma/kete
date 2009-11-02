class Comment < ActiveRecord::Base
  # comments unique feature is that they are attached to another item
  # this code is adapted from the acts_as_commentable plugin
  # http://www.juixe.com/techknow/index.php/2006/06/18/acts-as-commentable-plugin/
  # however, we do user contribution tracking, searchability, etc.
  # through our standard kete content item stuff (see include below)
  belongs_to :commentable, :polymorphic => true

  ZOOM_CLASSES.each do |zoom_class|
    unless zoom_class == 'Comment'
      belongs_to "direct_#{zoom_class.tableize.singularize}".to_sym, :class_name => zoom_class, :foreign_key => "commentable_id"
    end
  end

  # we order by position in relation to item commented on
  acts_as_list :scope => :commentable_id
  acts_as_nested_set

  # all the common configuration is handled by this module
  include ConfigureAsKeteContentItem

  include ItemPrivacy::ActsAsVersionedOverload
  include ItemPrivacy::TaggingOverload

  validates_presence_of :description

  # most likely we won't use versioning for comments
  # but we provide it for consistency sake with the rest of kete
  # however, we definitely don't need to keep track of what the comment is on
  # in the versioning table
  self.non_versioned_columns << 'commentable_id'
  self.non_versioned_columns << 'commentable_type'

  # Do not version commentable privacy.
  self.non_versioned_columns << 'commentable_private'

  # Do not version nested set fields since they can't change
  self.non_versioned_columns << 'parent_id'
  self.non_versioned_columns << 'lft'
  self.non_versioned_columns << 'rgt'

  # pulled almost directly from acts_as_commentable
  # Helper class method to look up all comments for
  # commentable class name and commentable id.
  def self.find_comments_for_commentable(commentable_str, commentable_id)
    find(:all,
      :conditions => ["commentable_type = ? and commentable_id = ?", commentable_str, commentable_id],
      :order => "position"
    )
  end

  # pulled almost directly from acts_as_commentable
  # Helper class method to look up a commentable object
  # given the commentable class name and id
  def self.find_commentable(commentable_str, commentable_id)
    commentable_str.constantize.find(commentable_id)
  end


  # We need to pretend to respond to privacy related methods in order
  # for the customized ActsAsZoom to store the comment record in the
  # correct Zebra instance.
  def private?
    commentable_private?
  end

  def private
    commentable_private
  end

  def private=(*args)
    self.commentable_private = *args
  end

  def has_private_version?
    commentable_private?
  end

  def should_save_to_private_zoom?
    commentable_private?
  end

  def private_version(&block)
    block.call
  end

  def to_anchor
    "comment-#{id}"
  end

end
