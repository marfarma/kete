class DocumentsController < ApplicationController
  include ExtendedContentController

  def index
    redirect_to_search_for('Document')
  end

  def list
    index
  end

  def show
    if !has_all_fragments? or params[:format] == 'xml'
      @document = @current_basket.documents.find(params[:id])
      @title = @document.title
    end

    if !has_fragment?({:part => 'contributions' }) or params[:format] == 'xml'
      @creator = @document.creator
      @last_contributor = @document.contributors.last || @creator
    end

    if !has_fragment?({:part => 'comments' }) or !has_fragment?({:part => 'comments-moderators' }) or params[:format] == 'xml'
      @comments = @document.comments
    end

    respond_to do |format|
      format.html
      format.xml { render_oai_record_xml(:item => @document) }
    end
  end

  def new
    @document = Document.new
  end

  def create
    @document = Document.new(extended_fields_and_params_hash_prepare(:content_type => @content_type, :item_key => 'document', :item_class => 'Document'))
    @successful = @document.save

    # add this to the user's empire of creations
    # TODO: allow current_user whom is at least moderator to pick another user
    # as creator
    if @successful
      @document.creator = current_user

      @document.do_notifications_if_pending(1, current_user)
    end

    setup_related_topic_and_zoom_and_redirect(@document)
  end

  def edit
    @document = Document.find(params[:id])
  end

  def update
    @document = Document.find(params[:id])

    version_after_update = @document.max_version + 1

    if @document.update_attributes(extended_fields_and_params_hash_prepare(:content_type => @content_type, :item_key => 'document', :item_class => 'Document'))

      after_successful_zoom_item_update(@document)

      @document.do_notifications_if_pending(version_after_update, current_user)

      flash[:notice] = 'Document was successfully updated.'

      redirect_to_show_for(@document)
    else
      render :action => 'edit'
    end
  end

  # converts uploaded document to document description in html form
  def convert
    @document = Document.find(params[:id])
    if @document.do_conversion
      after_successful_zoom_item_update(@document)
      flash[:notice] = 'Document description was successfully updated with text of uploaded document.'
    else
      flash[:notice] = 'There were problems converting the text of the uploaded document to the document\'s description.  Please edit the description manually.'
    end
    redirect_to_show_for(@document)
  end

  def make_theme
    @document = Document.find(params[:id])
    @document.decompress_as_theme
    flash[:notice] = 'Document expanded to be new theme.'
    redirect_to :action => :appearance, :controller => 'baskets'
  end

  def destroy
    zoom_destroy_and_redirect('Document')
  end
end
