require 'RMagick'
require 'twitter'
require 'yaml'
require 'openuri'
require 'httparty'

class Pittscard

  def initialize
    @time = Time.now.to_i.to_s
    set_configs
  end

  def tweet
    create_pittscard
    start_client
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
    @tweet = "text"
  end

  def create_image
    original_photo = grab_image_of_pittsburgh
  end
    
  # private 
  def grab_image_of_pittsburgh
    # Pull 500 images from Wikipedia associated w/ Pittsburgh
    # and filter out the ones end in "svg" or "tif" and the ones
    # that have "logo" in their names. Those will be less funny.
    list_of_pictures = JSON.parse(HTTParty.get('https://en.wikipedia.org/w/api.php?action=opensearch&format=json&namespace=6&search=pittsburgh&limit=500').body).last.select{|url| url !~ /(svg|tif)$/i}.select{|url| url !~ /logo/i}
    # Pick one of the remaining 450 or so images and download it.
    photo_url = list_of_pictures.sample
    extension = photo_url.match(/\w*$/)[0]
    filename = "orig-pittsburgh-#{@time}.#{extension}"
    open(photo_url) do |f|
      File.open(filename, "wb") do |file|
        file.puts f.read
      end
    end
    filename
  end

  def get_blacklist
    # Grab the list of bad words from Darius.
    @blacklist = JSON.parse(HTTParty.get("https://raw.githubusercontent.com/dariusk/wordfilter/master/lib/badwords.json").body)
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
