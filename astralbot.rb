# astralbot.rb
# A being of pure energy and light that exists solely to fav your selfies.

require 'open-uri'
require 'rubygems'

require 'opencv'
require 'twitter'

include OpenCV

BOT_NAME = "astralbot"
BOT_VERSION = "1.0.3"


def botlog(text)
	puts "#{Time.now.strftime("%Y:%m:%d %I:%M:%S")} - #{text}"
end

def configure_twitter(path_to_credentials_file)
	twitter_consumer_key = "consumer key placeholder"
	twitter_consumer_secret = "consumer secret placeholder"
	twitter_access_token = "access token placeholder"
	twitter_access_token_secret = "access token secret placeholder"

	begin
		File.open(path_to_credentials_file, 'r').each_line do |line|
			components = line.strip.split('=')
			if (components[0] == 'twitter_consumer_key')
				twitter_consumer_key = components[1]
			elsif (components[0] == 'twitter_consumer_secret')
				twitter_consumer_secret = components[1]
			elsif (components[0] == 'twitter_access_token')
				twitter_access_token = components[1]
			elsif (components[0] == 'twitter_access_token_secret')
				twitter_access_token_secret = components[1]
			end
		end
	rescue => err
		botlog "Couldn't open twitter credentials file. Error: #{err}"
		return nil
	end

	client = Twitter::REST::Client.new do |config|
		config.consumer_key = twitter_consumer_key
		config.consumer_secret = twitter_consumer_secret
		config.access_token = twitter_access_token
		config.access_token_secret = twitter_access_token_secret
	end

	client.connection_options[:headers][:user_agent] = "#{BOT_NAME}/#{BOT_VERSION}"

	return client
end

def directory_for_script
	File.expand_path(File.dirname(__FILE__))
end

def fetch_last_tweet_id
	last_tweet_id = nil

	begin
		file = File.new("#{directory_for_script()}/last_tweet.txt", "r")
		while (line = file.gets)
			last_tweet_id = line
		end
		file.close
	rescue => err
		botlog("Couldn't open last tweet file. Error: #{err}")
	end
	
	return last_tweet_id
end

def image_contains_face?(path_to_image)
	cascades = ["#{directory_for_script()}/opencv_cascades/haarcascade_frontalface_default.xml", "#{directory_for_script()}/opencv_cascades/haarcascade_frontalface_alt.xml", "#{directory_for_script()}/opencv_cascades/haarcascade_frontalface_alt2.xml", "#{directory_for_script}/opencv_cascades/haarcascade_frontalface_alt_tree.xml"]

	passed_classifier_count = 0

	cascades.each do |cascade|
		detector = CvHaarClassifierCascade::load(cascade)
		image = CvMat.load(path_to_image)
		detected_objects = detector.detect_objects(image)

		if (detected_objects.count > 0) and (detected_objects.count < 3)
			passed_classifier_count += 1
		end
	end

	# This seems like the best balance between getting rid of
	# images that don't have a legitimate face and not rejecting
	# too many good ones. Open to rebalancing this in the future
	# or coming up with an altogether different approach.

	if (passed_classifier_count >= 3)
		return true
	else
		return false
	end
end

def redirect_output
	$stdout = File.new("#{directory_for_script()}/#{BOT_NAME}.log", "a")
	$stderr.reopen($stdout)

	$stdout.sync = true
	$stderr.sync = true
end

def restore_output
	$stdout = STDOUT
	$stderr = STDERR
end

def saved_last_tweet_id?(last_tweet_id)
	did_save = false

	unless (last_tweet_id.nil?)
	  begin
		file = File.new("#{directory_for_script()}/last_tweet.txt", "w")
		file.write(last_tweet_id.to_s)
		file.close

		did_save = true
	  rescue => err
		botlog("Couldn't write to last tweet file. Error: #{err}")
	  end
	else
	  botlog("Last tweet ID was nil.")
	end

	return did_save
end

# Prepare for search.

redirect_output()
client = configure_twitter("#{directory_for_script()}/.twitter_credentials")
last_tweet_id = fetch_last_tweet_id()

# Search for selfie tweets.

candidate_id = nil
respondable_tweets = []

results = client.search("selfie -rt filter:links", :result_type => "recent", :since_id => last_tweet_id.to_i, :include_entities => true)

results.take(100).collect do |tweet|
  	if candidate_id.nil? or tweet.id.to_i > candidate_id
		candidate_id = tweet.id.to_i
  	end

	if (tweet.id.to_i <= last_tweet_id.to_i)
		next
	end

  	# A simple heuristic to filter out tweets that have a significant
  	# probability of being junk.

  	# 1. Text contains the word selfie.
	if (not tweet.text.downcase.include?("selfie"))
  		next
  	end

  	# 2. Tweet has a single, Twitter hosted image.
  	botlog("media count: #{tweet.media.count}")
  	if (not tweet.media?) or (tweet.media.count > 1)
  		next
  	end

	# 3. Tweet has a single link (to the image).
	if (tweet.uris?)
		next
	end	

  	# 4. No @ mentions.
  	if tweet.user_mentions?
  		next
  	end

  	# 5. No hashtags, unless there's only one and it's #selfie.
  	if tweet.hashtags? and not ((tweet.hashtags.count == 1) and \
	   (tweet.hashtags.first.text.downcase == "selfie"))
  		next
  	end

	# 6. There's a wierd thing where a lot of hashtags are crammed
	# together with no spaces and these don't get counted as
	# hashtags by Twitter. Here's a simple regex to try and avoid them.
	if tweet.text =~ /(#selfie#)|(\S#selfie)/i
		next
	end	
	
	# 7. Tweets that start with "when" seem to have a high chance
	# of being a fake image that isn't of the user.
	if tweet.text.downcase.start_with?("when")
		next
	end

	# Make sure the image contains a face.
	
	url = tweet.media.first.attrs[:media_url]
	open_failure_flag = false
	image_file = "#{directory_for_script()}/selfie_candidate.png"	

	File.open(image_file, 'wb') do |file_handle|
		begin
			file_handle.write open(url).read
		rescue => err
			botlog("Couldn't save image locally. Error: #{err}")
			open_failure_flag = true
		end
	end

	if not open_failure_flag and image_contains_face?(image_file)
		respondable_tweets << tweet
	end
end

# Mark tweets as favorite (at most 3 per round).

should_take_action_this_round = saved_last_tweet_id?(candidate_id)
if should_take_action_this_round
	if respondable_tweets.count > 3
		respondable_tweets = respondable_tweets.sample(3)
	end

	# Keep a list of users that are favorited so we don't mark
	# multiple tweets by a single user in the same round.
	
	users_favorited = []
	respondable_tweets.each do |tweet|
		user = tweet.attrs[:user]
		user_id = user[:id]

		if (not users_favorited.include?(user_id))
			begin
				client.favorite(tweet.id)
				botlog("Favoriting: #{tweet.id}")
				users_favorited << user_id
			rescue => err
				botlog("Couldn't favorite. Error: #{err}")
			end
		end
	end
end

restore_output()

