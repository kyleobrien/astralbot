# astralbot.rb
# A being of pure energy and light that exists solely to fav your selfies.

require 'open-uri'
require 'rubygems'

require 'opencv'
require 'twitter'

include OpenCV

BOT_NAME = "astralbot"
BOT_VERSION = "1.0.0"


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
	cascades = ["./opencv_cascades/haarcascade_frontalface_default.xml", "./opencv_cascades/haarcascade_frontalface_alt.xml", "./opencv_cascades/haarcascade_frontalface_alt2.xml", "./opencv_cascades/haarcascade_frontalface_alt_tree.xml"]

	passed_classifier_count = 0

	cascades.each do |cascade|
		detector = CvHaarClassifierCascade::load(cascade)
		image = CvMat.load(path_to_image)
		detected_objects = detector.detect_objects(image)
		if (detected_objects.count > 0) and (detected_objects.count < 3)
			passed_classifier_count += 1
		end
	end

	# This seems like the best balance between getting rid of images that don't
	# have a legitimate face and not rejecting too many good ones. Open to
	# rebalancing this in the future or coming up with an altogether different approach.

	if (passed_classifier_count >= 3)
		return true
	else
		return false
	end
end

def redirect_standard_output
	$stdout = File.new("#{directory_for_script()}/#{BOT_NAME}.log", "a")
	$stdout.sync = true
end

def restore_standard_output
	$stdout = STDOUT
end

def save_last_tweet_id(last_tweet_id)
	should_take_action_this_round = false

	unless (last_tweet_id.nil?)
	  begin
		file = File.new("#{directory_for_script()}/last_tweet.txt", "w")
		file.write(last_tweet_id.to_s)
		file.close

		should_take_action_this_round = true
	  rescue => err
		botlog("Couldn't write to last tweet file. Error: #{err}")
	  end
	else
	  botlog("Last tweet ID was nil. Shoul skip action this round.")
	end

	return should_take_action_this_round
end


#redirect_standard_output()
client = configure_twitter("#{directory_for_script()}/.twitter_credentials")
last_tweet_id = fetch_last_tweet_id()

# Search for selfie tweets and pick out which ones we want to take action on.

candidate_last_tweet_id = nil
respondable_tweet_ids = []

results = client.search("selfie -rt filter:links", :result_type => "recent", :since_id => last_tweet_id.to_i, :include_entities => true)
results.take(100).collect do |tweet|
	# Keep track of the largest tweet ID.
  	if (candidate_last_tweet_id.nil?) or (tweet.id.to_i > candidate_last_tweet_id)
		candidate_last_tweet_id = tweet.id.to_i
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
  	if (not tweet.media?) or (tweet.media.count > 1)
  		next
  	end

  	# 3. No @ mentions.
  	if tweet.user_mentions?
  		next
  	end

  	# 4. No hashtags, unless there's only one and it's #selfie.
  	if tweet.hashtags? and not (tweet.hashtags.first.text == "selfie")
  		next
  	end

	url = tweet.media.first.attrs[:media_url]
	
	File.open("selfie_candidate.png", 'wb') do |file_handle|
		begin
			file_handle.write open(url).read
		rescue => err
			botlog("Could save image locally. Error: #{err}")
			next
		end
	end

	if image_contains_face?("selfie_candidate.png")
		respondable_tweet_ids << tweet.id
	end
end

if respondable_tweet_ids.count <= 3
	respondable_tweet_ids.each do |id|
		#client.favorite(id)
	end
else
	respondable_tweet_ids.sample(3).each do |id|
		#client.favorite(id)
	end
end

should_take_action_this_round = save_last_tweet_id(candidate_last_tweet_id)
restore_standard_output()
