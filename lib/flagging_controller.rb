module FlaggingController
  unless included_modules.include? FlaggingController
    # set up our helper methods
    def self.included(klass)
      klass.helper_method :can_preview?
    end

    # user or moderater can add message with flagging
    def flag_form
      @flag = params[:flag]
      @form_target = @flag != REJECTED_FLAG ? 'flag_version' : 'reject'

      # use one form template for all controllers
      render :template => 'topics/flag_form'
    end

    def flag_version
      setup_flagging_vars

      # Revert to the passed in version if applicable
      @item.revert_to(params[:version]) if !params[:version].blank?
      
      # we tag the current version with the flag passed
      # and revert to an unflagged version
      # or create a blank unflagged version if necessary
      flagged_version = @item.flag_live_version_with(@flag, @message)

      # Reload to public version so zoom code works as expected
      @item.reload
      
      raise "We are not on public version" if @item.respond_to?(:private) && @item.private?

      flagging_clear_caches_and_update_zoom(@item)

      clear_caches_and_update_zoom_for_commented_item(@item)

      @item.notify_moderators_immediatelly_if_necessary(:flag => @flag,
                                                        :history_url => history_url(@item),
                                                        :flagging_user => @current_user,
                                                        :version =>  @version,
                                                        :submitter => @submitter,
                                                        :message => @message)

      flash[:notice] = "Thank you for your input.  A moderator has been notified and will review the item in question. The item has been reverted to a non-contested version for the time being."
      redirect_to @item_url
    end

    def flagging_clear_caches_and_update_zoom(item)
      # clear caches for the item and rss
      expire_show_caches
      expire_rss_caches

      # a before filter has already dropped the item
      # from the search
      # only reinstate it
      # if not blank
      # update zoom for item
      prepare_and_save_to_zoom(item) if !item.already_at_blank_version?
    end

    # permission check in controller
    # reverts to version
    # and removes flags on that version
    def restore
      setup_flagging_vars
      
      # if version we are about to supersede
      # is blank, flag it as blank for clarity in the history
      # this doesn't do the reversion in itself
      @item.flag_at_with(@item.version, BLANK_FLAG) if @item.already_at_blank_version?

      # unlike flag_version, we create a new version
      # so we track the restore in our version history
      @item.revert_to(@version)
      
      # James - 2009-01-16
      # If the version we're restoring to is invalid, then the moderator must improve the content
      # to make it valid before restoring the version.
      # unless true
        name_for_params = @item.class.table_name.singularize
        eval("@#{name_for_params} = @item")
        @editing = true
        
        # We need topic types for editing a topic
        @topic_types = @topic.topic_type.full_set if @item.is_a?(Topic)
        
        # Set the version comment
        params[name_for_params.to_sym] = {}
        params[name_for_params.to_sym][:version_comment] = "Content from revision # #{@version}."
        
        flash[:notice] = "The version you're reverting to is missing some compulsory content. Please contribute the missing details before continuing."
        render :action => 'edit'
        return true
      # end
      
      @item.tag_list = @item.raw_tag_list
      @item.version_comment = "Content from revision \# #{@version}."
      @item.do_not_moderate = true
      # turn off sanitizing in restores
      # for the rare case when invalid code made it in
      # otherwise validation may cause save action to fail
      @item.do_not_sanitize = true
      
      versions_before_save = @item.versions.size
      
      if @item.respond_to?(:save_without_saving_private!)
        @item.save_without_saving_private!
      else
        @item.save!
      end
      
      # If the version is not what we expect, there may have been a race condition.
      logger.debug "Race condition during restore. Version expected to be #{versions_before_save + 1} but was #{@item.version}." unless @item.version == versions_before_save + 1

      # keep track of the moderator's contribution
      @item.add_as_contributor(@current_user)
      
      # now that this item is approved by moderator
      # we get rid of pending flag
      # then flag it as reviewed
      @item.change_pending_to_reviewed_flag(@version)

      # Return to latest public version before changing flags..
      @item.send :store_correct_versions_after_save if @item.respond_to?(:store_correct_versions_after_save)

      flagging_clear_caches_and_update_zoom(@item)

      clear_caches_and_update_zoom_for_commented_item(@item)

      approval_message = 'Your contribution to ' + PRETTY_SITE_NAME + ' '
      approval_message += 'in ' + @current_basket.name + ' ' if @current_basket != @site_basket
      approval_message += 'has been made the live version.'


      # notify the contributor of this revision
      UserNotifier.deliver_approval_of(@version,
                                       @item_url,
                                       @submitter,
                                       approval_message)


      flash[:notice] = "The content of this #{zoom_class_humanize(@item.class.name)} has been approved from the selected revision."

      redirect_to @item_url
    end

    def reject
      setup_flagging_vars

      @item.reject_this(@version, @message)

      # notify the contributor of this revision
      UserNotifier.deliver_rejection_of(@version,
                                        correct_url_for(@item, @version),
                                        @submitter,
                                        @message)

      flash[:notice] = "This version of this #{zoom_class_humanize(@item.class.name)} has been rejected.  The user who submitted the revision will be notified by email."

      redirect_to @item_url
    end

    # view history of edits to an item
    # including each version's flags
    # this expects a rhtml template within each controller's view directory
    # so that different types of items can have their history display customized
    def history
      @item = item_from_controller_and_id
      
      # Only show private versions to authorized people.
      if permitted_to_view_private_items?
        @versions = @item.versions
      else
        @versions = @item.versions.reject { |v| v.respond_to?(:private) and v.private? }
        @show_private_versions_notice = (@versions.size != @item.versions.size)
      end
      
      @current_public_version = @item.version

      @item.private_version do 
        @current_private_version = @item.version
      end if @item.respond_to?(:private_version)

      # one template (with logic) for all controllers
      render :template => 'topics/history'
    end

    # preview a version of an item
    # assumes a preview templates under the controller
    def preview
      setup_flagging_vars
      
      # no need to preview live version
      if @item.version.to_s == @version
        redirect_to correct_url_for(@item)
      else
        @creator = @item.creator
        @last_contributor = @submitter || @creator
        @preview_version = @item.versions.find_by_version(@version)
        @flags = Array.new
        @flag_messages = Array.new
        @preview_version.taggings.each do |tagging|
          @flags << tagging.tag.name
          @flag_messages << tagging.message if !tagging.message.blank?
        end
        @item.revert_to(@preview_version)

        # Do not allow access to private item versions..
        if @item.respond_to?(:private?) && @item.private? && !permitted_to_view_private_items?
          raise ActiveRecord::RecordNotFound
        end

        # one template (with logic) for all controllers
        render :template => 'topics/preview'
      end
    rescue ActiveRecord::RecordNotFound
      flash[:notice] = "There is currently no public version of this #{params[:controller].singularize} available."
      redirect_to :controller => 'account', :action => 'login'
    end

    def can_preview?(options = { })
      submitter = options[:submitter] || options[:item].submitter_of(options[:version_number])
      @at_least_a_moderator or @current_user == submitter or !@current_basket.fully_moderated?
    end

    private
    def setup_flagging_vars
      @item = item_from_controller_and_id
      @flag = !params[:flag].blank? ? params[:flag] : nil
      @version = !params[:version].blank? ? params[:version] : @item.version
      if !params[:message].blank? and !params[:message][0].blank?
        @message =  params[:message][0]
      else
        @message = String.new
      end
      @item_url = correct_url_for(@item)
      @submitter = @item.submitter_of(@version) if !@version.nil?
    end
  end
end
