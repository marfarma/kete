class TopicsController < ApplicationController
  # since we use dynamic forms based on topic_types and topic_type_fields
  # and topics have their main attributes stored in an xml doc
  # within their content field
  # in fact none of the topics table fields are edited directly
  # we don't do CRUD for topics directly
  # instead we override CRUD here, as well as show
  # and use app/views/topics/_form.rhtml to customize
  # we'll start with using the override syntax for ajaxscaffold
  # the code should easily transferred to something else if we decide to drop it

  ### ajaxscaffold stuff
  include AjaxScaffold::Controller

  after_filter :clear_flashes
  before_filter :update_params_filter

  def update_params_filter
    update_params :default_scaffold_id => "topic", :default_sort => nil, :default_sort_direction => "asc"
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
    @sort_sql = Topic.scaffold_columns_hash[current_sort(params)].sort_sql rescue nil
    @sort_by = @sort_sql.nil? ? "#{Topic.table_name}.#{Topic.primary_key} asc" : @sort_sql  + " " + current_sort_direction(params)
    @paginator, @topics = paginate(:topics, :order => @sort_by, :per_page => default_per_page)

    render :action => "component", :layout => false
  end

  # this is code not generated by ajaxscaffold
  def pick_topic_type
    # we need to set the topic_type_id from a select box
    # add topic_type_id to params before forwarding the request to new
    @successful = true

    return render(:action => 'pick.rjs') if request.xhr?

    # Javascript disabled fallback
    if @successful
      @options = { :action => "create" }
      render :partial => "new_edit", :layout => true
    else
      return_to_main
    end
  end
  # end code not generated

  def new
    @topic = Topic.new
    @successful = true

    return render(:action => 'new.rjs') if request.xhr?

    # Javascript disabled fallback
    if @successful
      @options = { :action => "pick_topic_type" }
      render :partial => "pick", :layout => true
    else
      return_to_main
    end
  end

  def create
    begin
      # since this is creation, grab the topic_type fields
      topic_type = TopicType.find(params[:topic_type_id])
      params[:topic][:topic_type_id] = params[:topic_type_id]
      @fields = topic_type.topic_type_to_field_mappings

      # create the value for name_for_url

      # TODO: elimenate this HACK for determining name_for_url
      # ultimately I would like url's for peole to do look like the following:
      # topics/people/mcginnis/john
      # topics/people/mcginnis/john_marshall
      # topics/people/mcginnis/john_robert
      # for places:
      # topics/places/nz/wellington/island_bay/the_parade/206
      # events:
      # topics/events/2006/10/31
      # in the meantime we'll just use :name or :first_names and :last_names
      # TODO: helper for downcasing and underscoring
      name_1_key = @fields[0].topic_type_field_name.downcase.gsub(/ /, '_')
      n_for_url = params[name_1_key]

      if topic_type.name == "Person"
        # this assumes first_names and last_names are 0 and 1 in list
        name_2_key = @fields[1].topic_type_field_name.downcase.gsub(/ /, '_')
        n_for_url = "#{n_for_url} #{params[name_2_key]}"
      else
      end
      params[:topic][:name_for_url] = n_for_url.downcase.gsub(/ /, '_')

      # here's where we populate the content with our xml
      params[:topic][:content] = render_to_string(:partial => 'field_to_xml',
                                                  :collection => @fields,
                                                  :layout => false)

      @topic = Topic.new(params[:topic])
      @successful = @topic.save
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

  # TODO: modify to generate dynamic form based on topic_type_id
  def edit
    begin
      @topic = Topic.find(params[:id])
      @successful = !@topic.nil?
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

  # TODO: modify to render_to_string and rxml
  # to take the dynamic attributes from the form
  # and create the value for name_for_url
  # and content
  def update
    begin
      @topic = Topic.find(params[:id])
      topic_type = TopicType.find(@topic.topic_type_id)
      params[:topic][:topic_type_id] = params[:topic_type_id]
      @fields = topic_type.topic_type_to_field_mappings

      # create the value for name_for_url

      # TODO: elimenate this HACK for determining name_for_url
      # ultimately I would like url's for peole to do look like the following:
      # topics/people/mcginnis/john
      # topics/people/mcginnis/john_marshall
      # topics/people/mcginnis/john_robert
      # for places:
      # topics/places/nz/wellington/island_bay/the_parade/206
      # events:
      # topics/events/2006/10/31
      # in the meantime we'll just use :name or :first_names and :last_names
      # TODO: helper for downcasing and underscoring
      name_1_key = @fields[0].topic_type_field_name.downcase.gsub(/ /, '_')
      n_for_url = params[name_1_key]

      if topic_type.name == "Person"
        # this assumes first_names and last_names are 0 and 1 in list
        name_2_key = @fields[1].topic_type_field_name.downcase.gsub(/ /, '_')
        n_for_url = "#{n_for_url} #{params[name_2_key]}"
      else
      end
      params[:topic][:name_for_url] = n_for_url.downcase.gsub(/ /, '_')

      # here's where we populate the content with our xml
      params[:topic][:content] = render_to_string(:partial => 'field_to_xml',
                                                  :collection => @fields,
                                                  :layout => false)

      @successful = @topic.update_attributes(params[:topic])
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
      @successful = Topic.find(params[:id]).destroy
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
  ### end ajaxscaffold stuff
end
