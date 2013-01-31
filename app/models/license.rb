class License < ActiveRecord::Base
  uses_translations
  # this is only used in testing. For some translted models we only want to create one instance for a particular
  # label in a language. For example we only want one English DataType.image or one Rank.species. But other
  # models like License is translating a description which isn't unique. We can have several Licences with
  # description 'all rights reserved'. We need to know this when creating test data
  TRANSLATIONS_ARE_UNIQUE = false
  has_many :data_objects
  has_many :resources

  attr_accessible :title, :source_url, :version, :logo_url, :show_to_content_partners

  def small_logo_url
    return logo_url if logo_url =~ /_small/ # already there!
    return logo_url.sub(/\.(\w\w\w)$/, "_small.\\1")
  end

  def self.valid_for_user_content
    find_all_by_show_to_content_partners(1).collect {|c| [c.title, c.id] }
  end

  def self.public_domain
    cached_find(:title, 'public domain')
  end
  class << self
    alias default public_domain
  end

  def self.cc
    cached_find(:title, 'cc-by 3.0')
  end

  def self.by_nc
    cached_find(:title, 'cc-by-nc 3.0')
  end

  def self.by_nc_sa
    cached_find(:title, 'cc-by-nc-sa 3.0')
  end

  def self.by_sa
    cached_find(:title, 'cc-by-sa 3.0')
  end

  def self.no_known_restrictions
    cached_find(:title, 'no known copyright restrictions')
  end

  # we have several different licenses with the title public domain
  # NOTE - this *does* work in other languages (I checked), though I'm honestly not sure why; I didn't dig.
  def is_public_domain?
    self.title == 'public domain'
  end

  def show_rights_holder?
    !(is_public_domain? || self.id == License.no_known_restrictions.id)
  end
end
