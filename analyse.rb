#!/usr/bin/env ruby

require 'json'
require 'sqlite3'
require 'yaml'

#Look for configuration file, if not found give useful error message then exit
  if File.exists?('RooProbeMail.conf')
    # file found, continue
  else
    puts "The configuration file is missing."
    puts "Copy the file 'RooProbeMail.conf.sample' to 'RooProbeMail.conf'"
    puts "and remember to update it for your username/password"
    puts "then please try again"
    exit
  end


#Read the configuration file
rooprobemail_conf = YAML::load_file('RooProbeMail.conf')

@sqlitedb = rooprobemail_conf["config"]["sqlitedb"]

#Look for database file, if not found give useful error message then exit
  if File.exists?(@sqlitedb)
    # database found, continue
  else
    puts @sqlitedb
    puts "The database file is missing."
    puts "You probably need to run 'get_envelopes_into_db.rb' first."
    exit
  end


# Defaults you can configure

  db = SQLite3::Database.new rooprobemail_conf["config"]["sqlitedb"]
  limit = 20


# The defaults can be overriden during each run by the user.

print "How many results to return [default=#{limit}]?"
STDOUT.flush
  user_input = gets.chomp
  if user_input.empty?
    #limit unchanged
  else
    limit = user_input.to_i
  end
# XXX TODO XXX if a non integer is entered, it's treated as 0
# but it should be treated as use the default.
puts "you said #{limit} results"

print "In future, this will prompt for which queries you want to run"
STDOUT.flush




# A class for the queries and result display
class Queries
  def initialize(db,limit)
	@db = db #SQLite3::Database.new "gmail_envelopes.db"
	@limit = limit

  end

  def MailboxTotalSize
  puts "Total size of mailbox"
  puts "bytes, MB"
  puts '---------------------'
  sql = "SELECT sum(mail_size) as totalbytes, sum(mail_size)/1024/1024 as MB
	FROM emails"
  i=0
  @db.execute(sql) do |row|
    puts  "#{row[0]}, #{row[1]}"
    i = i+row[0]
    end
  puts "Total #{i/1024/1024} MB"
  puts ""
  end

  def LargestEmails
   puts "largest emails"
   puts '---------------------'
   puts "Date, MB, sender, subject"
   sql = "SELECT mail_date, mail_size/1024/1024 as MB, mail_from_mailbox||'@'||mail_from_host as mail_from, mail_subject, mail_size
	FROM emails
	ORDER BY mail_size DESC LIMIT #{@limit}"
   i=0
   @db.execute(sql) do |row|
     puts  "#{row[0]}, #{row[1]}, #{row[2]}, #{row[3]}"
     i = i+row[4]
    end
  puts "Total #{i/1024/1024} MB"
  puts ""
  end

  def LargestOlderThan12MonthsEmails
   puts "largest emails more than 12 months old"
   puts '---------------------'
   puts "bytes, MB, sender, date, subject"
   sql = "SELECT mail_size as totalbytes, mail_size/1024/1024 as MB, mail_from_mailbox||'@'||mail_from_host as mail_from, mail_date, mail_subject
	FROM emails
	WHERE mail_date < date('now','-12 months')
	ORDER BY mail_size DESC LIMIT #{@limit}"
   i=0
   @db.execute(sql) do |row|
     puts  "#{row[0]}, #{row[1]}, #{row[2]}, #{row[3]}, #{row[4]}"
     i = i+row[0]
    end
  puts "Total #{i/1024/1024} MB"
  puts ""
  end

  def EmailsWithBadDates
   puts "EmailsWithBadDates"
   puts '---------------------'
   puts "sender, date, subject"
   sql = "SELECT mail_from_mailbox||'@'||mail_from_host as mail_from, mail_date, mail_subject
	FROM emails
	WHERE mail_date = date('1875-05-20')
	ORDER BY mail_date DESC LIMIT #{@limit}"
   i=0
   @db.execute(sql) do |row|
     puts  "#{row[0]}, #{row[1]}, #{row[2]}"
     i = i+1
    end
  puts "Found #{i} emails"
  puts ""
  end


  def SenderLargestByTotalSize
   puts "largest sender by total mail size"
   puts '---------------------'
   puts "bytes, MB, sender"
   sql = "SELECT sum(mail_size) as totalbytes, sum(mail_size)/1024/1024 as MB, mail_from_mailbox||'@'||mail_from_host as mail_from
	FROM emails
	GROUP BY mail_from ORDER BY sum(mail_size) DESC LIMIT #{@limit}"
   i=0
   @db.execute(sql) do |row|
     puts  "#{row[0]}, #{row[1]}, #{row[2]}"
     i = i+row[0]
    end
  puts "Total #{i/1024/1024} MB"
  puts ""
  end

  def SenderLargestDomain

  puts "largest sender by domain"
  puts '---------------------'
  puts "bytes, MB, sender domain"
sql = "SELECT sum(mail_size) as totalbytes, sum(mail_size)/1024/1024 as MB, '@'||mail_from_host as mail_from_domain
	FROM emails
	GROUP BY mail_from_domain ORDER BY sum(mail_size) DESC LIMIT #{@limit}"
  i=0
  @db.execute(sql) do |row|
    puts  "#{row[0]}, #{row[1]}, #{row[2]}"
    i = i+row[0]
  end
  puts "Total #{i/1024/1024} MB"
  puts ""
  end

  def SenderMostProlific

   puts "most prolific senders"
   puts "count, size MB, sender"
   puts '---------------------'
   sql = "SELECT count(mail_from_mailbox||'@'||mail_from_host) as mail_count, sum(mail_size)/1024/1024 as MB, mail_from_mailbox||'@'||mail_from_host as mail_from
	FROM emails
	GROUP BY mail_from ORDER BY count(mail_from_mailbox||'@'||mail_from_host) DESC LIMIT #{@limit}"
  i = 0
  @db.execute(sql) do |row|
    puts  "#{row[0]}, #{row[1]}, #{row[2]}"
    i = i+row[1]
  end
  puts "Total #{i} MB"
  end
end

#db.close
# How do I close the DB? I can't seem to create the connection
# outside the Queries class and use it, and I don't know how
# to close it once the query class has finished.

#eamils with the same title (and less than X senders)
#emails with similar starting titles


# Show the results

q = Queries.new(db,limit)

q.SenderMostProlific
q.MailboxTotalSize
q.SenderLargestByTotalSize
q.SenderLargestDomain
q.LargestEmails
q.LargestOlderThan12MonthsEmails
q.EmailsWithBadDates

#we should close the db connection
db.close

puts ""
puts "Analysis Complete"
