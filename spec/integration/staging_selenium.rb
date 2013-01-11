# encoding: utf-8
require File.dirname(__FILE__) + '/../spec_helper'
require 'capybara'

include ActionController::Caching::Fragments

describe 'Home page', :js => true do

  describe 'Languages' do
    after(:all) do
      visit 'http://staging.eol.org/set_language?language=en'
      I18n.locale = :en
    end

    ['zh-Hans', :ko, :de, :es, :fr, :gl, :nl, :tl, :mk, :sr, :ar].each do |lang|
      it "should minimally support #{lang}" do
        I18n.locale = lang
        visit "http://staging.eol.org/set_language?language=#{lang}&return_to=http%3A%2F%2Fstaging.eol.org"
        page.should have_content(I18n.t(:global_access_tagline))
        visit 'http://staging.eol.org/pages/7659/overview'
        page.should have_content('Delphinidae')
        page.should have_content(I18n.t(:learn_more_about_names_for_this_taxon))
      end
    end

  end

  it 'should load', :js => true do
    visit 'http://staging.eol.org/set_language?language=en&return_to=http%3A%2F%2Fstaging.eol.org'
    page.should have_content('EOL News')
  end

  it 'should find tiger' do
    visit "http://staging.eol.org/search?q=tiger"
    page.should have_content("You've arrived here by searching for tiger.")
    click_link "Click here to see other search results."
    page.should have_content("Panthera tigris")
    page.should have_content("Displaying 1 – 25 of") # I don't care how many, as long as > 25.
    check "type_taxon_concept"
    click_button "Filter"
    page.should have_content("691 results for tiger") # Okay, I *do* care about the number, here.  :\
  end

  it 'should find jrice' do
    visit "http://staging.eol.org/search?q=jrice"
    page.should have_content "6 results for jrice"
    click_link "jrice"
    page.should have_content "Activity"
    page.should have_content "My info"
  end

end