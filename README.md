# RooProbeMail

I have too much email in my gmail. Too much as in I've consumed almost the entire 15GB, not too many (as in having over 100,000 emails is fine for gmail but the total size of those emails is becoming a problem).

## What I tried

I tried a number of ways of working out which emails I could delete to recover storage space but none quite did what I needed;
IMAPSize - http://www.broobles.com/imapsize/ - came close to helping but is no longer in development. I think I tried it, I can't remember now.
Mozilla Thunderbird - there was some way of viewing all the email, sorting by size, then deleting. It was slow and cumbersome. I gather there's a way of storing attachments offline using this but I didn't find that effective for my way of working.
Gmails search - let me find and label emails over a certain size (10Mb) which helped identify some emails I could get rid of, but many I wanted to keep. It didn't help me find old newsletters and routine service emails that individually are small but build up to a noticable size.

Eventually, I realised what I really wanted was to be able to get the details of the emails into a database so I could interogate it and find out more about my email. Questions like: 
* Who has sent me the most emails
* Who has sent me the largest emails by total size
* What are the largest emails older than 12 months
* Any other things I want to know

From that, I can then write more specific queries in sql to identify things I can delete.  

I decided NOT to delete emails by code. That seems dangerous, so having identified emails I don't want (eg: where the sender is newsletter@example.com") I then use the gmail search and delete.  My initial queries helped me find 1GB of space through a combination of one sender of large emails (352Mb over 1200 emails), a few big single emails of 20MB+, and a few thousand server reports and newsletters.  

## How does this work
I wrote a small script in ruby to connect to gmail, get ALL of the email headers (date, sender, subject, size) and process them into a sqlite database file.
Then I wrote another script in ruby to run queries against that database file.

To use this yourself you'll need 
+ Ruby (I happen to be using 2.3.1) 
+ a Gmail account.  I had to generate an app specific password to connect.

# Steps to use
0) Read the code - it won't take long and you can follow along to see that your password isn't being sent anywhere and your emails aren't being deleted. (It uses the imap command 'examine' which is read only, but don't take my word for it if you value your email).
1) Download or clone these files into a directory on your computer.
2) Open that directory, copy the file `RooProbeMail.conf.sample` to `RooProbeMail.conf`.
3) Edit this file and add the things specific to you (your username and password)
4) Run the `get_envelopes_into_db.rb` script. For me on linux, I use the terminal and type `ruby get_envelopes_into_db.rb`
5) As the script runs, it will prompt you for whether you want to do a trial run of 30 days of emails. I'd suggest you do the trial first so you can see if there are any errors. On the second run, it will ask if you want to delete the existing database or make a backup copy.
6) Once the database has been completed, you can run `ruby analyse.rb` to run some queries against the local database.  Currently this outputs to the screen. Eventually I'll make it write the output to a file.

## Benchmarks
I didn't do any performance optimisation - it worked well for me first time. However, I tried a few different devices and I believe that having enough memory is more important than a fast internet connection.  My 100,000 email headers created a sqlite database of just 40Mb.

On a Digital Ocean VPS 8GB memory/4 core server, 101515 emails in 306 seconds

On a Virtual Machine on my laptop, connected via approx 7mbps ADSL, 4GB memory/2 core, 101516 emails in 492 seconds

On a Digital Ocean VPS 0.5GB memory/1 core server, 101516 emails in 856 seconds


## Suggestions?
You're welcome to add your own queries and make a pull request, or ask if you'd like a particular query written that you think others may benefit from.

