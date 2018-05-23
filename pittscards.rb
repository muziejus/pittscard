require 'RMagick'
require 'twitter'
require 'yaml'
require 'open-uri'
require 'httparty'
require 'nokogiri'

class Pittscard

  def initialize
    @time = Time.now.to_i.to_s
    set_configs
  end

  def tweet
    create_pittscard
    # puts @tweet
    # puts @tweet.length
    # puts "See above"
    @client.update_with_media @tweet, File.new('final.png')
  end

  def create_pittscard
    create_tweet
    create_image
  end

  def create_tweet
    # start_client
    # @tweet = "text"
    puts set_phrase
  end

  def create_image
    original_photo = grab_image_of_pittsburgh

  end
    
  # private 
  def set_phrase
    search_results = search_twitter
    # Now refine the results. Strip anything that doesn't have "Pittsburgh is" in it
    tweets = search_results.select{|t| t.match(/Pittsburgh is/)}
    # further refinement: turn "http://" & "\n" into "!" so it stops trimming
    # and then also trim everything before the "Pittsburgh is" phrase
    tweets = tweets.map{|t| t.gsub(/(\n|http)/, "!")}.map{|t| t.sub(/^.*Pittsburgh is/, "Pittsburgh is")}
    # now trim and add exclamation point.
    tweets = tweets.map{|t| t.sub(/(Pittsburgh is[^—".!]*)(.*)/, '\1').strip + "!"}
    phrase = nil
    while phrase.nil?
      candidate = tweets.sample
      # this could run forever… but it's not likely.
      if blacklist.select{|badword| candidate.downcase.include? badword }.length == 0 && candidate.length < 65
        phrase = candidate
      end
    end
    @phrase = phrase
  end

  def search_twitter
    #@client.search('"Pittsburgh is"', { result_type: "recent" }).map{ |tweet| tweet.full_text }
    results = []
    File.readlines("text.txt").each { |f| results << f.strip }
    results
  end

  def grab_image_of_pittsburgh
    # Pull 500 images from Wikipedia associated w/ Pittsburgh
    # and filter out the ones end in "svg" or "tif" and the ones
    # that have "logo" in their names. Those will be less funny.
    list_of_pictures = JSON.parse(HTTParty.get("https://en.wikipedia.org/w/api.php?action=opensearch&format=json&namespace=6&search=pittsburgh&limit=500").body).last.select{|url| url !~ /(svg|tif)$/i}.select{|url| url !~ /logo/i}
    # Pick one of the remaining 450 or so images and download it.
    photo_url = get_photo_from_wiki(list_of_pictures.sample)
    puts photo_url
    extension = photo_url.match(/\w*$/)[0]
    filename = "orig-pittsburgh-#{@time}.#{extension}"
    File.open("images/#{filename}", "wb") do |file|
      file.write open(photo_url).read
    end
    filename
  end

  def get_photo_from_wiki url
    # Wiki makes a page out of the file, so we need to get the file's url
    wiki_page = Nokogiri::HTML open(url)
    # Then get the link from the .fullMedia div
    wiki_page.at_css(".fullMedia").at_css("a")["href"].sub(/^/, "https:")
  end

  def blacklist
    # Grab the list of bad words from Darius.
    JSON.parse(HTTParty.get("https://raw.githubusercontent.com/dariusk/wordfilter/master/lib/badwords.json").body)
  end

  def start_client
    @client ||= Twitter::REST::Client.new do |config|
      config.consumer_key = @configs[:consumer_key]
      config.consumer_secret = @configs[:consumer_secret]
      config.access_token = @configs[:access_token]
      config.access_token_secret = @configs[:access_token_secret]
    end
  end

  def set_configs
    if File.exists? 'configs.yml'
      @configs = YAML::load_file 'configs.yml'
    else
      raise "No configs file"
    end
  end

end

card = Pittscard.new
card.create_pittscard
