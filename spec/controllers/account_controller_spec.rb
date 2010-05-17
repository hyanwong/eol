require File.dirname(__FILE__) + '/../spec_helper'

describe AccountController do

     describe "POST /account/forgot_password" do
        it "should deliver the signup email" do
          user = User.gen(:username => 'johndoe', :email => 'johndoe@example.com')
          user.save!
          # expect
          Notifier.should_receive(:deliver_forgot_password_email).with(user, 80)
          # when
          post :forgot_password, "user" => {"email" => "johndoe@example.com", "username" => "johndoe"}
        end
      
        it "should send email to a single account with requested email" do
          user1 = User.gen(:username => 'johndoe', :email => 'jd@example.com')
          user1.save!
          #expect
          Notifier.should_receive(:deliver_forgot_password_email).with(user1, 80)
          #when
          post :forgot_password, "user" => {"email" => "jd@example.com", "username" => ''}
        end
      
      end

      describe "POST /account/profile" do
        it "should not change password if user is not logged in" do
          user = User.gen(:username => 'johndoe', :email => 'johndoe@example.com')
          user.save!
          new_password = "newpass"
          old_hashed_password = User.find(user).hashed_password
          post :profile, "user" => {"id" => user.id, "entered_password" => new_password, "entered_password_confirmation" => new_password}
          User.find(user).hashed_password.should == old_hashed_password
        end

        it "should change password for a user" do
          user = User.gen(:username => 'johndoe', :email => 'johndoe@example.com')
          user.save!
          new_password = "newpass"
          session[:user] = :user
          session[:user_id] = user.id
          old_hashed_password = User.find(user).hashed_password
          post :profile, "user" => {"id" => user.id, "entered_password" => new_password, "entered_password_confirmation" => new_password}
          User.find(user).hashed_password.should_not == old_hashed_password
          User.find(user).hashed_password.should == User.hash_password(new_password)
        end
      
        it "should unset password wrongly remembered by a broswer" do
          user = User.gen(:username => 'johndoe', :email => 'johndoe@example.com')
          user.save!
          new_password = "newpass"
          old_hashed_password = User.find(user).hashed_password
          session[:user] = :user
          session[:user_id] = user.id
          post :profile, "user" => {"id" => user.id, "entered_password" => new_password, "entered_password_confirmation" => new_password}
          User.find(user).hashed_password.should_not == old_hashed_password
          User.find(user).hashed_password.should == User.hash_password(new_password)
          post :profile, "user" => {"id" => user.id, "entered_password" => new_password, "entered_password_confirmation" => ''}
          User.find(user).hashed_password.should == User.hash_password(new_password)
        end
      end

      describe "POST /account/signup" do
        it "should create agent record for a user during account creation" do
          Scenario.load :foundation
          post :signup, "user" => {"username" => "johndoe99", "email" => "johndoe99@example.com", "entered_password" => "password", "entered_password_confirmation" => "password", "given_name" => "John"}
          User.find_by_username("johndoe99").agent_id.to_i.should > 0
        end
      end

end
