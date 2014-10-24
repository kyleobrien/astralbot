astralbot
=========

A being of pure energy and light that exists solely to fav your selfies.

https://twitter.com/brandonnn/status/448294361692782592

Usage Notes
===========

Copy twitter_credentials to .twitter_credentials and replace with credentials from your Twitter developer account.

Changelog
=========

1.0.1 - Fixed bug where hashtag filtering wasn't working if first hastag was #selfie.
1.0.0 - Initial release.

Dependencies
============

+ [Twitter Gem](http://rubygems.org/gems/twitter)
+ [OpenCV](http://opencv.org)
+ [Ruby-OpenCV Gem](http://rubygems.org/gems/ruby-opencv)

Pseudocode
==========

1. Cron runs script at predetermined interval.
2. Authenticate with Twitter.
3. Grab last known Twitter ID from text file.
4. Request tweets with the word selfie, with a few restrictions.
5. For each tweet in the response, filter out tweets:
	+ older than last known ID,
	+ that don't contain the word selfie,
	+ that don't have a Twitter hosted image, or have more than one such image,
	+ having @ mentions,
	+ having hastags, unless only one that's #selfie,
	+ that don't have 1 or 2 faces as detected by a majority of OpenCV's frontal face algorithms.
6. Randonly picks at most 3 tweets to favorite.
7. Saves the most recently seen Tweet ID.

Future
======

+ Allow Instagram photos?
+ Better way to filter out retweets besides checking for "RT".
+ Keyword block list.

License
=======

Code is available under the MIT license. See the included LICENSE file for details.

