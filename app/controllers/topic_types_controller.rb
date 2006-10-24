class TopicTypesController < ApplicationController
  include AjaxScaffold::Controller

  after_filter :clear_flashes
  before_filter :update_params_filter

  def update_params_filter
    update_params :default_scaffold_id => "topic_type", :default_sort => nil, :default_sort_direction => "asc"
  end
  def index
    redirect_to :action => 'list'
  end
  def return_to_main
    # If you have multiple scaffolds on the same view then you will want to change this to
    # to whatever controller/action shows all the views
    # (ex: redirect_to :controller => 'AdminConsole', :action => 'index')
    redirect_to :action => 'list'
  end

  def list
  end

  # All posts to change scaffold level variables like sort values or page changes go through this action
  def component_update
    @show_wrapper = false # don't show the outer wrapper elements if we are just updating an existing scaffold
    if request.xhr?
      # If this is an AJAX request then we just want to delegate to the component to rerender itself
      component
    else
      # If this is from a client without javascript we want to update the session parameters and then delegate
      # back to whatever page is displaying the scaffold, which will then rerender all scaffolds with these update parameters
      return_to_main
    end
  end

  def component
    @show_wrapper = true if @show_wrapper.nil?
    @sort_sql = TopicType.scaffold_columns_hash[current_sort(params)].sort_sql rescue nil
    @sort_by = @sort_sql.nil? ? "#{TopicType.table_name}.#{TopicType.primary_key} asc" : @sort_sql  + " " + current_sort_direction(params)
    @paginator, @topic_types = paginate(:topic_types, :order => @sort_by, :per_page => default_per_page)

    render :action => "component", :layout => false
  end

  def new
    @topic_type = TopicType.new
    @successful = true

    return render(:action => 'new.rjs') if request.xhr?

    # Javascript disabled fallback
    if @successful
      @options = { :action => "create" }
      render :partial => "new_edit", :layout => true
    else
      return_to_main
    end
  end

  def create
    begin
      @topic_type = TopicType.new(params[:topic_type])
      @successful = @topic_type.save
    rescue
      flash[:error], @successful  = $!.to_s, false
    end

    return render(:action => 'create.rjs') if request.xhr?
    if @successful
      return_to_main
    else
      @options = { :scaffold_id => params[:scaffold_id], :action => "create" }
      render :partial => 'new_edit', :layout => true
    end
  end

  def edit
    begin
      @topic_type = TopicType.find(params[:id])
      @successful = !@topic_type.nil?
    rescue
      flash[:error], @successful  = $!.to_s, false
    end

    return render(:action => 'edit.rjs') if request.xhr?

    if @successful
      @options = { :scaffold_id => params[:scaffold_id], :action => "update", :id => params[:id] }
      render :partial => 'new_edit', :layout => true
    else
      return_to_main
    end
  end

  def update
    begin
      @topic_type = TopicType.find(params[:id])
      @successful = @topic_type.update_attributes(params[:topic_type])
    rescue
      flash[:error], @successful  = $!.to_s, false
    end

    return render(:action => 'update.rjs') if request.xhr?

    if @successful
      return_to_main
    else
      @options = { :action => "update" }
      render :partial => 'new_edit', :layout => true
    end
  end

  def destroy
    begin
      @successful = TopicType.find(params[:id]).destroy
    rescue
      flash[:error], @successful  = $!.to_s, false
    end

    return render(:action => 'destroy.rjs') if request.xhr?

    # Javascript disabled fallback
    return_to_main
  end

  def cancel
    @successful = true

    return render(:action => 'cancel.rjs') if request.xhr?

    return_to_main
  end
  def add_to_topic_type
    topic_type = TopicType.find(params[:id])

    # this is setup for a form that has multiple fields
    # we want to separate out plain form fields from required ones

    # params has a hash of hashes for field with field_id as the key
    params[:topic_type_field].keys.each do |field_id|
      field = TopicTypeField.find(field_id)

      # into the field's hash
      # now we can grab the field's attributes that are being updated
      params[:topic_type_field][field_id].keys.each do |to_add_attr|
        to_add_attr_value = params[:topic_type_field][field_id][to_add_attr]

        # if we are supposed to add the field
        if to_add_attr_value.to_i == 1

          # determine if it should be a required field
          # or just an optional one
          if to_add_attr =~ /required/
            topic_type.required_form_fields << field
          else
            topic_type.form_fields << field
          end
        end
      end
    end
    redirect_to :action => :index
    # TODO: figure out how to re-render with ajaxscaffold
    #redirect_to :action => :edit, :id => topic_type.id, :scaffold_id => :topic_type unless request.xhr?
  end
  def reorder_fields_for_topic_type
    # update position in the topic_type's form
    TopicTypeToFieldMapping.update(params[:mapping].keys, params[:mapping].values)
    # TODO: figure out how to re-render with ajaxscaffold
    # redirect_to(:action => :edit, :id => params[:id], :scaffold_id => :topic_type) unless request.xhr?
    redirect_to :action => :index
  end
end
