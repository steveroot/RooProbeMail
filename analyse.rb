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
@resultfile = rooprobemail_conf["config"]["results"]

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

# Look for an existing results file. If it exists, ask if there
# should be a backup before it's regenerated

if File.file?(@resultfile)
   puts "The results file already exists. What would you like to do?"
   puts "[D] Delete the old results file "
   puts "[R] Rename and keep or "
   puts "[Q] Quit the script and do nothing (default)"

   user_input = gets.chomp
case user_input
  when "D","d"
  File.delete(@resultfile)
  puts 'Old results file deleted'
  when "R","r"
  File.rename(@resultfile, @resultfile + '.' + Time.now.iso8601 + '.bak')
  puts 'Old results file renamed'
    else
      puts "Script exited without touching the existing results file"
  exit
  end
end
#Create the new results file ready to append results
@keepoutput = File.open( @resultfile,"w" )

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
puts "\n"

STDOUT.flush




# A class for the queries and result display
class Queries
  def initialize(db,limit)
	@db = db #SQLite3::Database.new "gmail_envelopes.db"
	@limit = limit

  end

  def MailboxTotalSize
  @var = "Total size of mailbox\n"
  @var = @var + "bytes, MB\n"
  @var = @var + "---------------------\n"
  sql = "SELECT sum(mail_size) as totalbytes, sum(mail_size)/1024/1024 as MB
	FROM emails"
  i=0
  @db.execute(sql) do |row|
    @var = @var + "#{row[0]}, #{row[1]}\n"
    i = i+row[0]
    end
  @var = @var + "Total #{i/1024/1024} MB\n"
  @var = @var + "\n"

  puts @var
  return @var

  end

  def LargestEmails
  @var = "largest emails\n"
  @var = @var + "---------------------\n"
  @var = @var + "Date, MB, sender, subject\n"
   sql = "SELECT mail_date, mail_size/1024/1024 as MB, mail_from_mailbox||'@'||mail_from_host as mail_from, mail_subject, mail_size
	FROM emails
	ORDER BY mail_size DESC LIMIT #{@limit}"
   i=0
   @db.execute(sql) do |row|
     @var = @var + "#{row[0]}, #{row[1]}, #{row[2]}, #{row[3]}\n"
     i = i+row[4]
    end
  @var = @var + "Total #{i/1024/1024} MB\n"
  @var = @var + "\n"
  puts @var
  return @var
  end

  def LargestOlderThan12MonthsEmails
   @var = "largest emails more than 12 months old\n"
   @var = @var + "---------------------\n"
   @var = @var + "bytes, MB, sender, date, subject\n"
   sql = "SELECT mail_size as totalbytes, mail_size/1024/1024 as MB, mail_from_mailbox||'@'||mail_from_host as mail_from, mail_date, mail_subject
	FROM emails
	WHERE mail_date < date('now','-12 months')
	ORDER BY mail_size DESC LIMIT #{@limit}"
   i=0
   @db.execute(sql) do |row|
     @var = @var + "#{row[0]}, #{row[1]}, #{row[2]}, #{row[3]}, #{row[4]}\n"
     i = i+row[0]
    end
  @var = @var +  "Total #{i/1024/1024} MB\n"
  @var = @var +  "\n"
  puts @var
  return @var
  end

  def EmailsWithBadDates
   @var = "EmailsWithBadDates\n"
   @var = @var + "---------------------\n"
   @var = @var +  "sender, date, subject\n"
   sql = "SELECT mail_from_mailbox||'@'||mail_from_host as mail_from, mail_date, mail_subject
	FROM emails
	WHERE mail_date = date('1875-05-20')
	ORDER BY mail_date DESC LIMIT #{@limit}"
   i=0
   @db.execute(sql) do |row|
     @var = @var +   "#{row[0]}, #{row[1]}, #{row[2]}\n"
     i = i+1
    end
  @var = @var +  "Found #{i} emails"
  @var = @var +  "\n"
  puts @var
  return @var
  end


  def SenderLargestByTotalSize
   @var = "largest sender by total mail size\n"
   @var = @var + "---------------------\n"
   @var = @var +  "bytes, MB, sender\n"
   sql = "SELECT sum(mail_size) as totalbytes, sum(mail_size)/1024/1024 as MB, mail_from_mailbox||'@'||mail_from_host as mail_from
	FROM emails
	GROUP BY mail_from ORDER BY sum(mail_size) DESC LIMIT #{@limit}"
   i=0
   @db.execute(sql) do |row|
     @var = @var +   "#{row[0]}, #{row[1]}, #{row[2]}\n"
     i = i+row[0]
    end
  @var = @var +  "Total #{i/1024/1024} MB\n"
  @var = @var +  "\n"
  puts @var
  return @var
  end

  def SenderLargestDomain

  @var = "largest sender by domain\n"
  @var = @var + "---------------------\n"
  @var = @var +  "bytes, MB, sender domain\n"
sql = "SELECT sum(mail_size) as totalbytes, sum(mail_size)/1024/1024 as MB, '@'||mail_from_host as mail_from_domain
	FROM emails
	GROUP BY mail_from_domain ORDER BY sum(mail_size) DESC LIMIT #{@limit}"
  i=0
  @db.execute(sql) do |row|
    @var = @var +   "#{row[0]}, #{row[1]}, #{row[2]}\n"
    i = i+row[0]
  end
  @var = @var +  "Total #{i/1024/1024} MB\n"
  @var = @var +  "\n"
  puts @var
  return @var
  end

  def SenderMostProlific

   @var = "most prolific senders\n"
   @var = @var +  "count, size MB, sender\n"
   @var = @var + "---------------------\n"
   sql = "SELECT count(mail_from_mailbox||'@'||mail_from_host) as mail_count, sum(mail_size)/1024/1024 as MB, mail_from_mailbox||'@'||mail_from_host as mail_from
	FROM emails
	GROUP BY mail_from ORDER BY count(mail_from_mailbox||'@'||mail_from_host) DESC LIMIT #{@limit}"
  i = 0
  @db.execute(sql) do |row|
    @var = @var +   "#{row[0]}, #{row[1]}, #{row[2]}\n"
    i = i+row[1]
  end
  @var = @var +  "Total #{i} MB\n"
  @var = @var +  "\n"
  puts @var
  return @var
  end

end

#db.close
# How do I close the DB? I can't seem to create the connection
# outside the Queries class and use it, and I don't know how
# to close it once the query class has finished.

#eamils with the same title (and less than X senders)
#emails with similar starting titles


# Show the results
# The function prints to screen as well as outputs to the file
q = Queries.new(db,limit)

@keepoutput << q.SenderMostProlific
@keepoutput << q.MailboxTotalSize
@keepoutput << q.SenderLargestByTotalSize
@keepoutput << q.SenderLargestDomain
@keepoutput << q.LargestEmails
@keepoutput << q.LargestOlderThan12MonthsEmails
@keepoutput << q.EmailsWithBadDates


#we should close the db connection
db.close
#we should close the results file too
@keepoutput.close

puts ""
puts "Analysis Complete"
