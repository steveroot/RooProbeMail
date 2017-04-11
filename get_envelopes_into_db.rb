#!/usr/bin/env ruby

# Written by Steve Root
# www.sroot.eu

# XXX TODO XXX add licence
# XXX TODO XXX add description, link to github

require 'net/imap'
require 'json'
require 'sqlite3'
require 'time'
require 'yaml'

#record process start time
start = Time.now

#Look for configuration file, if not found give useful error message then exit
  if File.exists?('RooProbeMail.conf')
    #
  else
    puts "The configuration file is missing."
    puts "Copy the file 'RooProbeMail.conf.sample' to 'RooProbeMail.conf'"
    puts "and remember to update it for your username/password"
    puts "then please try again"
    exit
  end

#Read the configuration file
rooprobemail_conf = YAML::load_file('RooProbeMail.conf')
 # put variables into easier words
  @sqlitedb = rooprobemail_conf["config"]["sqlitedb"]
  @server = rooprobemail_conf["config"]["server"]
  @ssl = rooprobemail_conf["config"]["ssl"]
  @user = rooprobemail_conf["config"]["user"]
  @password = rooprobemail_conf["config"]["password"]


# Check to see if the database is already present, if it is ask if it should
# be replaced. Default is no (and script will stop)

STDOUT.flush
  #user_input = gets.chomp
  if File.file?(@sqlitedb)
     puts "The database already exists. What would you like to do?"
     puts "[D] Delete the old database "
     puts "[R] Rename and keep or "
     puts "[Q] Quit the script and do nothing (default)"

     user_input = gets.chomp
	case user_input
		when "D","d"
		File.delete(@sqlitedb)
		puts 'Old database deleted'
		when "R","r"
		File.rename(@sqlitedb, @sqlitedb + '.' + Time.now.iso8601 + '.bak') 
		puts 'Old database renamed'
  		else
    		puts "Script exited without touching the existing database"
		exit
  	end
  end	




# Connect to imap server
imap = Net::IMAP.new(@server, ssl: @ssl)
imap.login(@user,@password)

#Querying imap server
# Examine is read only, a safer setting than allowing a script to delete your email.
imap.examine("[Google Mail]/All Mail")

puts "Getting all the emails can take a long time. I suggest"
puts " you have a trial run and collect the last 30 days of "
puts " email first?"

puts "[A] All emails"
puts "[T] Trial run of last 30 days email (default)"

user_input = gets.chomp
  case user_input
    when "A","a"
    selectuids = imap.uid_search(['ALL','NOT','DELETED'])
    puts "Getting every email from the server, this may take a while..."
    else
    thisday = (Date.today).strftime('%d-%b-%Y')
    monthago = (Date.today << 1).strftime('%d-%b-%Y')

    # You can set your own dates, uncomment and change these lines
    #thisday = '28-Jan-2016'
    #monthago = '1-Jan-2016'

    selectuids = imap.uid_search(['SINCE',monthago,'BEFORE',thisday,'NOT','DELETED'])
    puts "Getting email between #{monthago} and #{thisday}"

    # You can use other searches here too, here's an example finding all mails with
    # a particular subject
    #selectuids = imap.uid_search(["SUBJECT","Can we talk?"])
    
  end

getmails = imap.uid_fetch(selectuids,["ENVELOPE","RFC822.SIZE"])

puts "We have #{selectuids.count} emails, processing them into a database..."

#Possible Future Task - option to overwrite/refresh database of emails (not getting new data will be faster and if no actions have been carried out to change things, why request all again?

# Open a database
db = SQLite3::Database.new @sqlitedb

# Create a database
rows = db.execute(
  '''create table emails(
    email_uid int,
    mail_size int,
    mail_date text,
    mail_subject text,
    mail_from_name text,
    mail_from_mailbox text,
    mail_from_host text, 
    mail_sender_name text,
    mail_sender_mailbox text,
    mail_sender_host text,
    mail_reply_to_name text,
    mail_reply_to_mailbox text,
    mail_reply_to_host text,
    mail_to_name text,
    mail_to_mailbox text,
    mail_to_host text,
    mail_cc text,
    mail_bcc text,
    mail_in_reply_to text,
    mail_message_id text
  )'''
)

counter = 0
getmails.each do |m|
# For debugging, this will output the envelope to the screen before
# it gets processed.

#puts "SHOW ENVELOPE: "+m.attr.fetch("ENVELOPE").to_json

# For normal use, this prints a dot every 100 + label every 1000 mails processed.
# this is a little faster than the full envelope but still shows things are happening.
counter = counter + 1
thousands = counter/1000
if counter%1000==0
  then print "[#{counter}]"
  else if counter%100==0 then print '.' end
end


# now we process the envelope into a set of variables ready for our database
# some elements are arrays if they're present, or nil if they are not. I have
# to check for an array before trying to get the value or ruby will error
  email_uid = m.attr.fetch("UID")
  mail_size = m.attr.fetch("RFC822.SIZE")
begin 
  mail_date = Date.parse(m.attr.fetch("ENVELOPE").date).iso8601
rescue ArgumentError
  # An email may have an invalid date. When this happens I chose to use May 20th 1875, 
  # the date of the metric convention being signed in Paris. The analysis database 
  # queries can then highlight these emails. This is also the reference date for the
  # ISO 8601 date format.
  # https://en.wikipedia.org/wiki/ISO_8601 
  mail_date = "1875-05-20"
end
 
  mail_subject = m.attr.fetch("ENVELOPE").subject
  mail_from_name = if m.attr.fetch("ENVELOPE").from.kind_of?(Array)
			then m.attr.fetch("ENVELOPE").from[0].name else "" end
  mail_from_mailbox = if m.attr.fetch("ENVELOPE").from.kind_of?(Array)
			then m.attr.fetch("ENVELOPE").from[0].mailbox else "" end
  mail_from_host = if m.attr.fetch("ENVELOPE").from.kind_of?(Array)
			then m.attr.fetch("ENVELOPE").from[0].host else "" end
  #sender = m.attr.fetch("ENVELOPE").sender.to_json
  mail_sender_name = if m.attr.fetch("ENVELOPE").sender.kind_of?(Array)
			then m.attr.fetch("ENVELOPE").sender[0].name else "" end
  mail_sender_mailbox = if m.attr.fetch("ENVELOPE").sender.kind_of?(Array)
			then m.attr.fetch("ENVELOPE").sender[0].mailbox else "" end

  mail_sender_host = if m.attr.fetch("ENVELOPE").sender.kind_of?(Array) 
			then m.attr.fetch("ENVELOPE").sender[0].host
			else "" end
  mail_reply_to_name = if m.attr.fetch("ENVELOPE").reply_to.kind_of?(Array)
			then  m.attr.fetch("ENVELOPE").reply_to[0].name else "" end
  mail_reply_to_mailbox = if m.attr.fetch("ENVELOPE").reply_to.kind_of?(Array)
			then m.attr.fetch("ENVELOPE").reply_to[0].mailbox else "" end
  mail_reply_to_host = if m.attr.fetch("ENVELOPE").reply_to.kind_of?(Array)
			then m.attr.fetch("ENVELOPE").reply_to[0].host else "" end
  #to = m.attr.fetch("ENVELOPE").to.to_json
  mail_to_name = if m.attr.fetch("ENVELOPE").to.kind_of?(Array) 
			then m.attr.fetch("ENVELOPE").to[0].name else "" end
  mail_to_mailbox = if m.attr.fetch("ENVELOPE").to.kind_of?(Array) 
			then  m.attr.fetch("ENVELOPE").to[0].mailbox else "" end
  mail_to_host = if m.attr.fetch("ENVELOPE").to.kind_of?(Array) 
          		then m.attr.fetch("ENVELOPE").to[0].host else "" end
  mail_cc = m.attr.fetch("ENVELOPE").cc.to_json
  mail_bcc = m.attr.fetch("ENVELOPE").bcc.to_json
  mail_in_reply_to = m.attr.fetch("ENVELOPE").in_reply_to
  mail_message_id = m.attr.fetch("ENVELOPE").message_id



  db.execute "insert into emails (email_uid,
    mail_size,
    mail_date,
    mail_subject,
    mail_from_name,
    mail_from_mailbox,
    mail_from_host, 
    mail_sender_name,
    mail_sender_mailbox,
    mail_sender_host,
    mail_reply_to_name,
    mail_reply_to_mailbox,
    mail_reply_to_host,
    mail_to_name,
    mail_to_mailbox,
    mail_to_host,
    mail_cc,
    mail_bcc,
    mail_in_reply_to,
    mail_message_id) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
[email_uid,
    mail_size,
    mail_date,
    mail_subject,
    mail_from_name,
    mail_from_mailbox,
    mail_from_host, 
    mail_sender_name,
    mail_sender_mailbox,
    mail_sender_host,
    mail_reply_to_name,
    mail_reply_to_mailbox,
    mail_reply_to_host,
    mail_to_name,
    mail_to_mailbox,
    mail_to_host,
    mail_cc,
    mail_bcc,
    mail_in_reply_to,
    mail_message_id]


end

puts "database created"

#Find a few rows

#db.execute( "select * from emails" ) do |row|
#  p row
#end
puts ""
puts "====== A small test query ================"
puts "Top 5 senders by total mail size"
puts "Email, size(MB)"
puts "------------------------------------------"

sql = "SELECT sum(mail_size) as totalbytes, sum(mail_size)/1024/1024 as MB, mail_from_mailbox||'@'||mail_from_host as mail_from 
	FROM emails 
	GROUP BY mail_from ORDER BY sum(mail_size) DESC LIMIT 5"

db.execute(sql) do |row|
puts  "#{row[2]}, #{row[1]}MB"
end
puts "=========================================="

# Total size of mailbox
sql = "SELECT sum(mail_size) as totalbytes, sum(mail_size)/1024/1024 as MB
	FROM emails"
  i=0
  db.execute(sql) do |row|
    i = i+row[0]
    end
  puts "Total size of mailbox #{i/1024/1024} MB"
  puts ""

db.close

puts "You can run 'analyse.rb' to find out more about your email"

# how long did this take?
finish = Time.now

diff = finish - start

puts "Processed #{selectuids.count} emails in #{diff.round(0)} seconds"

