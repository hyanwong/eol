class FeedsController < ApplicationController
  
  #/feeds/images/25 or texts or comments or all
  before_filter :set_session_hierarchy_variable
  caches_page :all, :images, :texts, :comments, :expires_in => 2.minutes
  @@maximum_feed_entries = 50
  
  def all
    lookup_content(:type => :all)
  end
  
  def images
    lookup_content(:type => :images, :title => 'Latest Images')
  end

  def text
    lookup_content(:type => :text, :title => 'Latest Text')
  end
  
  def comments
    lookup_content(:type => :comments, :title => 'Latest Comments')
  end
  
  def lookup_content(options = {})
    taxon_concept_id = params[:id] || nil
    options[:type] ||= :all
    options[:title] ||= 'Latest Images, Text and Comments'
    begin
      taxon_concept = TaxonConcept.find(taxon_concept_id)
    rescue
      render_404
      return false
    end
    
    feed_link = url_for(:controller => :taxa, :action => :show, :id => taxon_concept.id)
    options[:title] += " for #{taxon_concept.quick_scientific_name(:normal, @session_hierarchy)}"
    
    feed_items = []
    if options[:type] != :comments
      feed_items += DataObject.for_feeds(options[:type], taxon_concept.id, @@maximum_feed_entries)
    end
    if options[:type] == :comments
      feed_items += Comment.for_feeds(:comments, taxon_concept_id, @@maximum_feed_entries)
    end
    
    self.create_feed(feed_items, :type => options[:type], :id => taxon_concept_id, :title => options[:title], :link => feed_link)
  end
  
  
  def create_feed(feed_items, options = {})
    @feed_url = url_for(:controller => 'feeds', :action => options[:type], :id => options[:id])
    @feed_link = options[:link] || root_url
    @feed_title = options[:title] || 'Latest Images, Text and Comments'
    
    
    feed_items.sort! {|x,y| y['created_at'] <=> x['created_at']}
    feed_items = feed_items[0..@@maximum_feed_entries]
    
    @feed_entries = []
    feed_items.each do |hash|
      @feed_entries << feed_entry(hash)
    end
    
    respond_to do |format|
      format.atom { render :template => '/feeds/feed_template', :layout => false }
    end
  end
  
  def feed_entry(hash)
    entry = { :id => '', :title => '', :link => '', :content => '', :updated => '' }
    
    link_type_id = :comment_id
    if hash['data_type_label'] == 'Image'
      link_type_id = :image_id
    elsif hash['data_type_label'] == 'Text'
      link_type_id = :text_id
    end
    
    entry[:title] = hash['scientific_name']
    entry[:link] = url_for(:controller => :taxa, :action => :show, :id => hash['taxon_concept_id'], link_type_id => hash['id'])
    #entry[:id] = hash['guid']
    entry[:id] = entry[:link]
    entry[:updated] = hash['created_at']
    
    content = hash['description'] + "<br/><br/>"
    if hash['data_type_label'] == 'Image'
      content = "<img src='#{DataObject.image_cache_path(hash['object_cache_url'])}'/></a><br/>" + content
    end
    
    content += "<b>License</b>: #{hash['license_label']}<br/>" unless hash['license_label'].blank?
    
    # add attribution
    unless hash["agents"].nil?
      for agent in hash["agents"]
        content += "<b>#{agent["role"].capitalize}</b>: #{agent["full_name"]}<br/>"
      end
    end
    entry[:content] = content
    return entry
  end








  def partner_curation()
    agent_id = params[:agent_id] || nil
    year = params[:year] || nil
    month = params[:month] || nil
    
    partner = Agent.find(agent_id, :select => [:full_name])
    partner_fullname = partner.full_name
    
    latest_harvest_id = Agent.latest_harvest_event_id(agent_id)        
    arr_dataobject_ids = HarvestEvent.data_object_ids_from_harvest(latest_harvest_id)
    
    do_detail = DataObject.get_object_cache_url(arr_dataobject_ids)
    
    arr = User.curated_data_object_ids(arr_dataobject_ids, year, month, agent_id)
    arr_dataobject_ids = arr[0]
    arr_user_ids = arr[1]
    
    if(arr_dataobject_ids.length == 0) then 
      arr_dataobject_ids = [1] #no data objects
    end
    
    arr_obj_tc_id = DataObject.tc_ids_from_do_ids(arr_dataobject_ids);
    partner_curated_objects = User.curated_data_objects(arr_dataobject_ids, year, month, 0, "rss feed")
    
    feed_items = []
    partner_curated_objects.each do |rec|
      if(arr_obj_tc_id["datatype#{rec.data_object_id}"])
        if(arr_obj_tc_id["datatype#{rec.data_object_id}"]=="text") then
          do_type = "Text"
        else
          do_type = "Image"
        end
      end
      
      unless arr_obj_tc_id["#{rec.data_object_id}"].blank?
        concept = TaxonConcept.find(arr_obj_tc_id["#{rec.data_object_id}"])
        tc_name = concept.quick_scientific_name
        updated_at = rec.updated_at.strftime("%d-%b-%Y") + " at " + rec.updated_at.strftime("%I:%M%p")
        
        feed_items << { "curator"   => rec.given_name + " " + rec.family_name,  
                 "activity"  => rec.code || nil, 
                 "do_type"   => do_type || nil,
                 "tc_id"     => arr_obj_tc_id["#{rec.data_object_id}"] || nil,
                 "do_id"     => rec.data_object_id || nil,
                 "tc_name"   => tc_name || nil,
                 "updated_at"       => updated_at,
                 "object_cache_url" =>  do_detail["#{rec.data_object_id}"] || nil,
                 "source_url" =>  do_detail["#{rec.data_object_id}_source"] || nil }
      end
    end
    
    @feed_url = url_for(:controller => 'feeds', :action => 'partner_curation', :agent_id => agent_id, :month => month, :year => year)
    @feed_link = "http://www.eol.org"
    @feed_title = partner_fullname + " curation activity"
    
    @feed_entries = []
    feed_items.each do |hash|
      @feed_entries << partner_feed_entry(hash)
    end
    
    respond_to do |format|
      format.atom { render :template => '/feeds/feed_template', :layout => false }
    end
  end

  def partner_feed_entry(hash)
    entry = { :id => '', :title => '', :link => '', :content => '', :updated => '' }
    
    pp hash
    entry[:title] = hash['tc_name']
    entry[:updated] = hash['updated_at']
    
    if(hash['do_type']=="Text") then
      entry[:link] = url_for(:controller => :taxa, :action => :show, :id => hash['tc_id'], :text_id => hash['do_id'])
    else
      entry[:link] = url_for(:controller => :taxa, :action => :show, :id => hash['tc_id'], :image_id => hash['do_id'])
    end
    entry[:id] = entry[:link]

    content = hash['do_type'] + " was changed to '" + hash['activity'] + "' by " + hash['curator'] + " last " + hash['updated_at'] + " " + "<br/><br/>"

    if hash['do_type'] == 'Image'
      content = "<img src='#{DataObject.image_cache_path(hash['object_cache_url'],'small')}'/><br/>" + content
    end
    
    # Will insert a link to a Wikipedia article
    # TODO - looking for oldid in the link isn't robust enough to determine the object is a Wikipedia article
    temp = hash['source_url']
    result = temp.split(/oldid=\s?/)
    revision_id = result[1] 
    if(revision_id) then
      content += "Revision ID: <a target='wikipedia' href='#{hash['source_url']}'/>#{revision_id}</a>"
    end
    
    entry[:content] = content
    return entry
  end
end
