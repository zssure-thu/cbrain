require 'spec_helper'

describe UsersController do
  let(:admin) {Factory.create(:user, :role => "admin")}
  let(:site_manager) {Factory.create(:user, :role => "site_manager")}
  let(:site_user) {Factory.create(:user, :site => site_manager.site)}
  let(:user) {Factory.create(:user)}
  let(:mock_user) {mock_model(User).as_null_object}
  
  context "collection action" do
    describe "index" do
      before(:each) do
        1.upto(3) {Factory.create(:user)}
      end
      context "with admin user" do
        before(:each) do
          session[:user_id] = admin.id
        end
        it "should sort by login by default" do
          get :index
          assigns[:users].should == User.all(:order => "users.login")
        end
        it "should sort by full name" do
          get :index, "users" => { "sort_hash"  => { "order" => "users.full_name" } }
          assigns[:users].should == User.all(:order => "users.full_name")
        end
        it "should sort by last connection" do
          get :index, "users" => { "sort_hash"  => { "order" => "users.last_connected_at" } }
          assigns[:users].should == User.all(:order => "users.last_connected_at")
        end
        it "should sort by site" do
          get :index, "users" => { "sort_hash"  => { "order" => "sites.name" } }
          assigns[:users].should == User.all(:include => :site, :order => "sites.name")
        end
        it "should sort by city" do
          get :index, "users" => { "sort_hash"  => { "order" => "users.city" } }
          assigns[:users].should == User.all(:order => "users.city")
        end
        it "should sort by country" do
          get :index, "users" => { "sort_hash"  => { "order" => "users.country" } }
          assigns[:users].should == User.all(:order => "users.country")
        end
      end
      context "with site manager" do
        before(:each) do
          session[:user_id] = site_manager.id
          1.upto(3) { Factory.create(:user, :site => site_manager.site) }
        end
        it "should only show users from site" do
          get :index
          assigns[:users].should =~ User.all(:conditions => {:site_id => site_manager.site_id})
        end
      end
      context "with regular user" do
        before(:each) do
          session[:user_id] = user.id
        end
        it "should return a 401 (unauthorized)" do
          get :index
          response.response_code.should == 401
        end
      end
    end
    describe "create" do
      before(:each) do
        CbrainMailer.stub!(:deliver_registration_confirmation)
      end
      context "with admin user" do
        before(:each) do
          session[:user_id] = admin.id
        end
        it "should allow the login to be set" do
          post :create, :user => {:login => "login"}
          assigns[:user].login.should == "login"
        end
        it "should allow role to be set to admin" do
          post :create, :user => {:role => "admin"}
          assigns[:user].role.should == "admin"
        end
        it "should allow role to be set to site manager" do
          post :create, :user => {:role => "site_manager"}
          assigns[:user].role.should == "site_manager"
        end
        it "should allow role to be set to user" do
          post :create, :user => {:role => "user"}
          assigns[:user].role.should == "user"
        end
        it "should allow the site to be set" do
          post :create, :user => {:site_id => user.site_id}
          assigns[:user].site_id.should == user.site_id
        end
        context "when save is successful" do
          before(:each) do
            User.stub!(:new).and_return(mock_user)
            mock_user.stub_chain(:errors, :empty?).and_return(true)
          end
          it "should send a confirmation email if email is valid" do
            mock_user.stub!(:email).and_return("me@here.com")
            CbrainMailer.should_receive(:deliver_registration_confirmation)
            post :create, :user => {}
          end
          it "should not send a confirmation email if email is invalid" do
            mock_user.stub!(:email).and_return("invalid_email")
            CbrainMailer.should_not_receive(:deliver_registration_confirmation)
            post :create, :user => {}
          end
        end
      end
      context "with site manager" do
        before(:each) do
          session[:user_id] = site_manager.id
        end
        it "should allow the login to be set" do
          post :create, :user => {:login => "login"}
          assigns[:user].login.should == "login"
        end
        it "should not allow role to be set to admin" do
          post :create, :user => {:role => "admin"}
          assigns[:user].role.should_not == "admin"
        end
        it "should allow role to be set to site manager" do
          post :create, :user => {:role => "site_manager"}
          assigns[:user].role.should == "site_manager"
        end
        it "should allow role to be set to user" do
          post :create, :user => {:role => "user"}
          assigns[:user].role.should == "user"
        end
        it "should automatically set site to manager's site'" do
          post :create, :user => {:site_id => user.site_id}
          assigns[:user].site_id.should == site_manager.site_id
        end
      end
      context "with site manager" do
        before(:each) do
          session[:user_id] = user.id
        end
        it "should return a 401 (unauthorized)" do
          post :create
          response.response_code.should == 401
        end
      end
    end
    describe "send_password" do
      before(:each) do
        CbrainMailer.stub!(:deliver_forgotten_password)
      end
      context "when user is found" do
        it "should set the users 'password reset' flag" do
          post :send_password, :login => user.login, :email => user.email
          assigns[:user].password_reset.should be_true
        end
        it "should change the password" do
          post :send_password, :login => user.login, :email => user.email
          assigns[:user].password.should_not == user.password
        end
        context "when reset is succesful" do
          it "should send an e-mail" do
            CbrainMailer.should_receive(:deliver_forgotten_password)
            post :send_password, :login => user.login, :email => user.email
          end
        end
        context "when reset fails" do
          it "should display flash message about problem" do
            mock_user = mock_model(User, :save => false).as_null_object
            User.stub!(:find).and_return(mock_user)
            post :send_password
            flash[:error].should =~ /^Unable to reset password/
          end
        end
      end
      context "when user is not found" do
        before(:each) do
          User.stub!(:find).and_return(nil)
        end
        it "should display flash message about problem" do
          post :send_password
          flash[:error].should =~ /^Unable to find user/
        end
      end
    end
  end
  context "member action" do
    describe "show" do
      context "with admin user" do
        before(:each) do
          session[:user_id] = admin.id
        end
        it "should show any user" do
          get :show, :id => user.id
          response.should render_template("show")
        end
      end
      context "with site manager" do
        before(:each) do
          session[:user_id] = site_manager.id
        end
        it "should show a user associated with the site" do
          get :show, :id => site_user.id
          response.should render_template("show")
        end
        it "should not show a user not associated with the site" do
          get :show, :id => user.id
          response.should redirect_to(:controller => :portal, :action => :welcome)
        end
      end
      context "with regular user" do
        before(:each) do
          session[:user_id] = user.id
        end
        it "should show self" do
          get :show, :id => user.id
          response.should render_template("show")
        end
        it "should not show other users" do
          get :show, :id => site_user.id
          response.should redirect_to(:controller => :portal, :action => :welcome)
        end
      end
    end
    describe "update" do
      context "with admin user" do
        before(:each) do
          session[:user_id] = admin.id
        end
        it "should allow role to be set to admin" do
          put :update, :id => user.id, :user => {:role => "admin"}
          assigns[:user].role.should == "admin"
        end
        it "should allow role to be set to site manager" do
          put :update, :id => user.id, :user => {:role => "site_manager"}
          assigns[:user].role.should == "site_manager"
        end
        it "should allow role to be set to user" do
          put :update, :id => user.id, :user => {:role => "user"}
          assigns[:user].role.should == "user"
        end
        it "should allow the site to be set" do
          put :update, :id => user.id, :user => {:site_id => user.site_id}
          assigns[:user].site_id.should == user.site_id
        end
        it "should allow me to add groups" do
          new_group = Factory.create(:work_group)
          put :update, :id => user.id, :user => {:group_ids => [new_group.id]}
          user.reload
          user.group_ids.should include(new_group.id)
        end
        it "should allow me to reset groups" do
          new_group = Factory.create(:work_group, :user_ids => [user.id])
          put :update, :id => user.id, :user => {:group_ids => []}
          user.reload
          user.group_ids.should_not include(new_group.id)
        end
        it "should add meta data" do
          controller.should_receive(:add_meta_data_from_form)
          put :update, :id => user.id
        end
      end
      context "with site manager" do
        before(:each) do
          session[:user_id] = site_manager.id
        end
        it "should not allow me to modify a user that does not belong to the site" do
          put :update, :id => user.id
          response.should redirect_to(:controller => :portal, :action => :welcome)
        end
        it "should not allow role to be set to admin" do
          put :update, :id => site_user.id, :user => {:role => "admin"}
          assigns[:user].role.should_not == "admin"
        end
        it "should allow role to be set to site manager" do
          put :update, :id => site_user.id, :user => {:role => "site_manager"}
          assigns[:user].role.should == "site_manager"
        end
        it "should allow role to be set to user" do
          put :update, :id => site_user.id, :user => {:role => "user"}
          assigns[:user].role.should == "user"
        end
        it "should automatically set site to manager's site'" do
          put :update, :id => site_user.id, :user => {:site_id => user.site_id}
          assigns[:user].site_id.should == site_user.site_id
        end
        it "should allow me to add groups" do
          new_group = Factory.create(:work_group)
          put :update, :id => site_user.id, :user => {:group_ids => [new_group.id]}
          site_user.reload
          site_user.group_ids.should include(new_group.id)
        end
        it "should allow me to reset groups" do
          new_group = Factory.create(:work_group, :user_ids => [site_user.id])
          put :update, :id => site_user.id, :user => {:group_ids => []}
          site_user.reload
          site_user.group_ids.should_not include(new_group.id)
        end
      end
      context "with regular user" do
        before(:each) do
          session[:user_id] = user.id
        end
        it "should not allow another user to be modified" do
          put :update, :id => site_user.id
          response.should redirect_to(:controller => :portal, :action => :welcome)
        end
        it "should not allow role to be modified" do
          put :update, :id => user.id, :user => {:role => "site_manager"}
          assigns[:user].role.should == user.role
        end
        it "should not allow site to be modified" do
          put :update, :id => user.id, :user => {:site_id => site_user.site_id}
          assigns[:user].site_id.should == user.site_id
        end
        it "should not allow groups to be" do
          new_group = Factory.create(:work_group)
          put :update, :id => user.id, :user => {:group_ids => [new_group.id]}
          user.reload
          user.group_ids.should_not include(new_group.id)
        end
      end
    end
    describe "destroy" do
      context "with admin user" do
        before(:each) do
          session[:user_id] = admin.id
        end
        it "should allow me to destroy a user" do
          delete :destroy, :id => user.id
          User.all.should_not include(user)
        end
        it "should render shared destroy js partial" do
          delete :destroy, :id => user.id
          response.should render_template("shared/_destroy")
        end
      end
      context "with site manager" do
        before(:each) do
          session[:user_id] = site_manager.id
        end
        it "should allow me to destroy a user from the site" do
          delete :destroy, :id => site_user.id
          User.all.should_not include(user)
        end
        it "should not allow me to destroy a user not from the site" do
          delete :destroy, :id => user.id
          User.all.should include(user)
        end
      end
      context "with regular user" do
        before(:each) do
          session[:user_id] = user.id
        end
        it "should return a 401 (unauthorized)" do
          post :create
          response.response_code.should == 401
        end
      end
    end
    describe "switch" do
      before(:each) do
        session.stub!(:model).and_return(double("session_class").as_null_object)
      end
      context "with admin user" do
        before(:each) do
          session[:user_id] = admin.id
        end
        it "should switch the current user" do
          post :switch, :id => user.id
          session[:user_id].should == user.id
        end
        it "should redirect to the welcome page" do
          post :switch, :id => user.id
          response.should redirect_to(:controller => :portal, :action => :welcome)
        end
      end
      context "with site manager" do
        before(:each) do
          session[:user_id] = site_manager.id
        end
        it "should allow switching to a user from the site" do
          post :switch, :id => site_user.id
          session[:user_id].should == site_user.id
        end
        it "should not allow switching to a user not from the site" do
          post :switch, :id => user.id
          session[:user_id].should_not == user.id
        end
      end
      context "with regular user" do
        before(:each) do
          session[:user_id] = user.id
        end
        it "should return a 401 (unauthorized)" do
          post :create
          response.response_code.should == 401
        end
      end    
    end
  end
    
 
  context "when the user is not logged in" do
    describe "index" do
      it "should redirect the login page" do
        get :index
        response.should redirect_to(:controller => :sessions, :action => :new)
      end
    end
    describe "show" do
      it "should redirect the login page" do
        get :show, :id => 1
        response.should redirect_to(:controller => :sessions, :action => :new)
      end
    end
    describe "edit" do
      it "should redirect the login page" do
        get :edit, :id => 1
        response.should redirect_to(:controller => :sessions, :action => :new)
      end
    end
    describe "create" do
      it "should redirect the login page" do
        post :create
        response.should redirect_to(:controller => :sessions, :action => :new)
      end
    end
    describe "update" do
      it "should redirect the login page" do
        put :update, :id => 1
        response.should redirect_to(:controller => :sessions, :action => :new)
      end
    end
    describe "destroy" do
      it "should redirect the login page" do
        delete :destroy, :id => 1
        response.should redirect_to(:controller => :sessions, :action => :new)
      end
    end
    describe "switch" do
      it "should redirect the login page" do
        post :switch, :id => 1
        response.should redirect_to(:controller => :sessions, :action => :new)
      end
    end
  end
  
end