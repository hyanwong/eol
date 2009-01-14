class ContentPartnerController < ApplicationController
  
  before_filter :agent_login_required, :except => [:login, :forgot_password, :register, :check_username, :forgot_password, :agreement]
  before_filter :accounts_not_available unless $ALLOW_USER_LOGINS  
  helper_method :current_agent, :agent_logged_in?
  layout 'main'
  
  # Dashboard
  def index
    @page_header='Content Partner Dashboard'    
  end
  
  def partner
    @page_header='Partner Information'
    @agent = current_agent
    @content_partner=@agent.content_partner
    @content_partner.step = :partner
    @agent.partner_step = true # for this step, the agent model needs special validation, so tell it where we are 
    
    @agent_data_types = AgentDataType.find(:all, :order => 'label')
    
    return unless request.post?
    
    params[:agent][:agent_data_type_ids] = [] unless params[:agent].key? :agent_data_type_ids
      
    if @agent.update_attributes(params[:agent])
     
      # call to resizing web service if there is a logo, then get result and store the url
      unless @agent.logo_file_name.blank?
        #parameters='function=partner_image&file_path=' + @agent.logo.path + '&server_ip=' + $IP_ADDRESS_OF_SERVER
        parameters='function=partner_image&file_path=http://' + $IP_ADDRESS_OF_SERVER + ":" + request.port.to_s + $LOGO_UPLOAD_PATH + @agent.id.to_s + "."  + @agent.logo_file_name.split(".")[-1]
        response=EOLWebService.call(:parameters=>parameters)
        if response.blank?
          ErrorLog.create(:url  => $WEB_SERVICE_BASE_URL, :exception_name  => "content partner logo upload service failed") if $ERROR_LOGGING
        else
          response = Hash.from_xml(response)
          if response["response"].key? "file_prefix"
            file_prefix = response["response"]["file_prefix"]
            @agent.update_attribute(:logo_cache_url,file_prefix) # store new url to logo on content server      
          end
          if response["response"].key? "error"
            error = response["response"]["error"]
            ErrorLog.create(:url=>$WEB_SERVICE_BASE_URL,:exception_name=>error,:backtrace=>parameters) if $ERROR_LOGGING
          end
        end
      end
      
      @agent.content_partner.log_completed_step!
      handle_save_type(:stay => { :action => action_name }, :next => { :action => 'add_contact' })
    end
    
  end
  
  def contacts
    @page_header='Contact Information'
    @agent = current_agent
    @content_partner=@agent.content_partner
    @content_partner.step  = :contacts
    @agent_contacts = @agent.agent_contacts.find(:all, :include => :agent_contact_role)

    return unless request.post?
    
    if @agent.update_attributes(params[:agent])
      @agent.content_partner.log_completed_step!
      handle_save_type(:stay => { :action => action_name }, :next => { :action => 'licensing' })
    end
    
  end
  
  def licensing
    @page_header='Partnering Steps'
    @agent = current_agent
    @content_partner=@agent.content_partner
    @content_partner.step  = :licensing
    
    @contact = AgentContactForm.new
    
    return unless request.post?
    
    if @content_partner.update_attributes(params[:content_partner])
      @content_partner.log_completed_step! 
      handle_save_type(:stay => { :action => action_name }, :next => { :action => 'attribution' })
    end
  end
  
  def attribution
    @page_header='Partnering Steps'
    @agent = current_agent
    @content_partner=@agent.content_partner
    @content_partner.step  = :attribution   
    
    return unless request.post?
    
    if @content_partner.update_attributes(params[:content_partner])
      @content_partner.log_completed_step!
      handle_save_type(:stay => { :action => action_name }, :next => { :action => 'roles' })      
    end
  end
    
  def roles
    @page_header='Partnering Steps'
    @agent = current_agent
    @content_partner=@agent.content_partner
    @agent.content_partner.step  = :roles
    
    return unless request.post?
    
    if @content_partner.update_attributes(params[:content_partner])
      @content_partner.log_completed_step!
      handle_save_type(:stay => { :action => action_name }, :next => { :action => 'transfer_overview' })      
    end
  end
  
  def transfer_overview
    @page_header='Partnering Steps'
    @agent = current_agent
    @content_partner = @agent.content_partner
    @content_partner.step  = :transfer_overview
    
    return unless request.post?
    
    if @content_partner.update_attributes(params[:content_partner])
      @content_partner.log_completed_step!
      handle_save_type(:stay => { :action => action_name }, :next => { :action => 'transfer_upload' })      
    end
  end
  
  def transfer_upload
    @page_header='Partnering Steps'
    @agent = current_agent
    @content_partner = @agent.content_partner
    @agent.content_partner.step  = :transfer_upload
    
    return unless request.post?

    if @content_partner.update_attributes(params[:content_partner])
      @content_partner.log_completed_step!
      handle_save_type(:stay => { :action => action_name }, :next => @agent.ready_for_agreement? ? resources_url : { :action => 'index' })      
    end    
  end
  
  # NOT BEING USED FOR NOW
  def specialist_overview
    @page_header='Specialist Project Overview'
    @agent = current_agent
    @content_partner = @agent.content_partner    
    @agent.content_partner.step  = :specialist_overview
    
    return unless request.post?

    if @content_partner.update_attributes(params[:content_partner])
      @content_partner.log_completed_step!    
      handle_save_type(:stay => { :action => action_name }, :next => { :action => 'specialist_formatting' })      
    end    
  end

  # NOT BEING USED FOR NOW
  def specialist_formatting
    @page_header='Specialist Project Formatting'    
    @agent = current_agent
    @content_partner = @agent.content_partner    
    @agent.content_partner.step  = :specialist_formatting
    
    return unless request.post?

    if @content_partner.update_attributes(params[:content_partner])
      @content_partner.log_completed_step!
      handle_save_type(:stay => { :action => action_name }, :next => { :action => 'index' })      
    end
    
  end  
 
  def preview
  end

  # General methods for misc things
  # ------------------------------------------

  def contact_us

    @page_header='Contact Us' 
    @contact = AgentContactForm.new(params[:contact])
    unless request.post? || current_agent.primary_contact.nil?
      @contact.name=current_agent.primary_contact.full_name 
      @contact.email=current_agent.primary_contact.email
    end
    @subject = params[:subject]
    return unless request.post?
    
    if @contact.save
      Notifier::deliver_agent_contact_form_email(current_agent, @contact, $CONTENT_PARTNER_REGISTRY_EMAIL_ADDRESS)
      redirect_to(:action => 'contact_thanks')
    end
  end
  
  def contact_thanks    
    @page_header='Thanks' 
  end
  
  def help
    @page_header="Help"
  end
    
  def agreement
    
    # TO UPDATE THE CONTENT PARTNER AGREEMENT TEMPLATE AND ENSURE THAT EACH PREVIOUS CONTENT PARTNER GETS A NEW ONE WITH THE NEWLY UPDATED TEMPLATE,
    # SET THEIR CURRENT CONTENT PARTNER AGREEMENT TO "IS_CURRENT=FALSE"
    agreement_id=params[:agreement_id] || ""
    
    # if we are calling this method from the content partner registry, the agent is currently logged in so use that one
    if agent_logged_in? && params[:id].nil?
      @agent=current_agent
    else #otherwise, show the agreement from the agent ID passed into the querystring (and the specific agreement if passed in)
      @agent=Agent.find(params[:id])
    end
    
    unless @agent.ready_for_agreement?
      flash[:warning] = "The agreement for this partner is not available."
      return
      redirect_to(:action => 'index')
    end
    
    # find their agreement
    if agreement_id.empty? 
      @agreement=@agent.agreement      
      # if this is the first time they are viewing the agreement, create it from the default template
      @agreement=ContentPartnerAgreement.create_new(@agent.id) if @agreement.nil?
      # update the number of views if the content partner is viewing it
      @agreement.update_attributes(:number_of_views=>@agreement.number_of_views+=1,:last_viewed=>Time.now) if !current_agent.nil?
    elsif current_user.is_admin?
      @agreement=ContentPartnerAgreement.find_by_id_and_agent_id(params[:agreement_id],@agent.id,:order=>'created_at DESC')
      @agreement=ContentPartnerAgreement.create_new(@agent.id) if @agreement.nil?
    end
    
    @primary_contact=@agent.primary_contact  
    
    if !@agreement.mou_url.blank?  # if there is a URL, render the url 
      redirect_to @agreement.mou_url
    else #otherwise render the template
      render :layout => false, :inline=>@agreement.template
    end
    
  end
  
  def accept_agreement
      
      return unless request.xhr?      

      agreement=current_agent.agreement
      agreement.signed_by=params[:signed_by]
      agreement.signed_on_date=Time.now
      agreement.ip_address=request.remote_ip
      agreement.save
      
      render :update do |page|
        page.replace_html 'save-message', 'Agreement accepted at ' + Time.now.to_s
      end
            
  end

  # Contact crud methods
  # ------------------------------------------
    
  def add_contact
    @page_header='Add Contact'
    @agent_contact = current_agent.agent_contacts.build(params[:agent_contact])
    @agent_contact_roles = AgentContactRole.find(:all)
    
    return unless request.post?
    
    if @agent_contact.save
      flash[:notice] = "Contact created"
      handle_save_type(:stay => { :action => 'edit_contact', :id => @agent_contact.id }, :next => { :action => 'contacts' })      
    end
  end

  def edit_contact
    @page_header='Edit Contact'
    @agent_contact = current_agent.agent_contacts.find(params[:id])
    @agent_contact_roles = AgentContactRole.find(:all)
    
    return unless request.post?
    
    if @agent_contact.update_attributes(params[:agent_contact])
      flash[:notice] = "Contact updated"
      handle_save_type(:stay => { :action => 'edit_contact', :id => @agent_contact.id }, :next => { :action => 'contacts' })      
    end
  end
  
  def del_contact
    @page_header='Delete Contact'
    @agent_contact = current_agent.agent_contacts.find(params[:id])
    
    if current_agent.agent_contacts.count > 1
      @agent_contact.destroy
      flash[:notice] = "Contact deleted"
    else
      flash[:error] = "You must have at least one contact"
    end

    redirect_to :action => 'contacts'
  end
  
  # Public authentication methods
  # ------------------------------------------
      
  def register
    @agent = Agent.new(params[:agent])
    
    return unless request.post?
    
    @agent.agent_status = AgentStatus.active

    if @agent.save
      @agent.content_partner=ContentPartner.new
      self.current_agent = @agent
      flash[:notice] = "Welcome"
      # Send to first step (partner information)
      redirect_to(:action => 'index')
    end
    
  end
  
  def check_username
    
    conditions=''
    conditions='id <> ' + current_agent.id.to_s unless current_agent.nil?
    
    agent = Agent.find_by_username(params[:username],:conditions=>conditions)
    
    message = agent ? "{username} is already taken"[:username_taken, agent.username] : ""

    message="" if params[:username].empty?
      
    render :update do |page|      
      page['username_warn'].replace_html(message)
    end
    
  end
  
  def login
    
    redirect_to :action => 'index' and return if agent_logged_in?    
    
    return unless request.post?

    # log out any logged in web user to avoid any funny conflicts
    reset_session
    
    self.current_agent = Agent.authenticate(params[:agent][:username], params[:agent][:password])
    if agent_logged_in?
      if params[:remember_me] == "1"
        self.current_agent.remember_me
        cookies[:agent_auth_token] = { :value => self.current_agent.remember_token , :expires => self.current_agent.remember_token_expires_at }
      end
      flash[:notice] = "Logged in successfully"
      agent_redirect_back_or_default(:action => 'index')
    else
      flash.now[:error] = 'Invalid login credentials'
    end
  end
  
  def logout
    self.current_agent.forget_me if agent_logged_in?
    cookies.delete :agent_auth_token
    reset_session   
    session[:agent_id] = nil
    flash[:notice] = "You have been logged out."
    redirect_to(:action => 'index')
  end
    
  def forgot_password
    return unless request.post?
    
    if params[:username] == '' # if user did not supply a username, just look by project
      @agent = Agent.find_by_full_name(params[:project_name])
    elsif params[:project_name] == '' # if user did not supply a project name, just look by username
      @agent = Agent.find_by_username(params[:username],true)
    else # otherwise look by both
      @agent = Agent.find_by_username_and_full_name(params[:username], params[:project_name])
    end
    if @agent
      new_password = @agent.reset_password!
      Notifier.deliver_agent_forgot_password_email(@agent, new_password)
      flash[:notice] = "A new password has been emailed to you at {email}."[:new_password_emailed, @agent.email]
      redirect_to(:action => 'login')
    else
      flash[:error] = "Unknown username or project name"
      redirect_to(:action => 'forgot_password')
    end    
  end
  
  def profile
    @page_header='Account Profile'
    @agent = current_agent
    
    return unless request.post?
    
    if @agent.update_attributes(params[:agent])
      flash[:notice] = "Profile updated"[]
      redirect_to(:action => 'profile')
    end
  end
        
  protected
  
    # Callbacks and internal helpers
    # ------------------------------------------
  
    def save_type
      params[:save_type] || 'next'
    end
    
    def handle_save_type(options = {})
      raise ArgumentError unless options[:stay] && options[:next]      
      redirect_to(save_type == 'save' ? options[:stay] : options[:next])
    end
  
end
