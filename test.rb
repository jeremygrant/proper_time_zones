require 'rubygems'
require 'activesupport'
require 'activerecord'
require 'bacon'
require 'facon'
require 'sqlite3'

# setting the default timezone to UTC
Time.zone_default = 'UTC'
puts Time.zone

# setting up active record like rails
ActiveRecord::Base.time_zone_aware_attributes = true
ActiveRecord::Base.default_timezone = :utc
ActiveRecord::Base.logger = Logger.new STDOUT

# connection to the database
#ActiveRecord::Base.establish_connection :adapter => "sqlite3", :database  => "test.sqlite3"
ActiveRecord::Base.establish_connection(:adapter => "postgresql", :database => "proper_time_zones_test", :username => "jgrant", :password => '')

class CreateArticles < ActiveRecord::Migration
  def self.up
    create_table :articles do |t|
      t.timestamp :published_at
      t.timestamps
    end
  end

  def self.down
    drop_table :articles
  end
end

class Article < ActiveRecord::Base
  named_scope :by_published, lambda{ |published_at|
    start_of_published_on = Time.zone.local_to_utc(published_at.to_date.to_time)
    # both of the following work to the second which appears to be the best precision that ruby Time has
    {:conditions => ["published_at between ? and ?", start_of_published_on, start_of_published_on + 1.day - 1.second]}
    #{:conditions => ["published_at >= ? and published_at < ?", start_of_published_on, (start_of_published_on + 1.day)]}
  }

  def published_on
    published_at.to_date
  end
end

CreateArticles.down rescue nil
CreateArticles.up

describe Article do
  %w(Samoa UTC Sydney Nuku'alofa).each do |timezone|
    describe "testing single time zone #{timezone}" do
      before do
        Time.zone = timezone
        @end_of_the_previous_day = Time.zone.parse "2009-10-07 23:59:59.999999"
        @start_of_the_day = Time.zone.parse "2009-10-08 00:00:00.000000"
        @end_of_the_day = Time.zone.parse "2009-10-08 23:59:59.999999"
        @start_of_the_next_day = Time.zone.parse "2009-10-09 00:00:00.000000"
        Article.create! :published_at => @end_of_the_previous_day
        Article.create! :published_at => @start_of_the_day
        Article.create! :published_at => @end_of_the_day
        Article.create! :published_at => @start_of_the_next_day
      end

      after do
        Article.destroy_all
      end

      it "should find the 2 articles on the local date 2009-10-08 using the start of the day" do
        time = @start_of_the_day
        Article.by_published(time).each do |article|
          article.published_on.to_s(:long).should.equal "October  8, 2009"
        end
      end

      it "should find 2 on the local date 2009-10-08 articles using the end of the day" do
        time = @end_of_the_day
        Article.by_published(time).each do |article|
          article.published_on.to_s(:long).should.equal "October  8, 2009"
        end
      end

      it "should find 2 on the local date 2009-10-08 articles using some arbitrary time of the day" do
        time = Time.zone.parse "2009-10-08 12:34:56.789012"
        Article.by_published(time).each do |article|
          article.published_on.to_s(:long).should.equal "October  8, 2009"
        end
      end

      it "should find 2 on the local date 2009-10-08 articles using some arbitrary time of the day" do
        time = Date.parse "2009-10-08"
        Article.by_published(time).each do |article|
          article.published_on.to_s(:long).should.equal "October  8, 2009"
        end
      end

    end
  end
end
