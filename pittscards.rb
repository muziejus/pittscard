require 'RMagick'
require 'twitter'
require 'yaml'
require 'open-uri'
require 'httparty'
require 'nokogiri'

class Pittscard
  include Magick

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
    # get the saved image of Pittsburgh
    @card = Image.read(File.join("images", grab_image_of_pittsburgh)).first
    # resize it to 800px wide
    @card = @card.resize(800, (800 * @card.rows) / @card.columns)
    build_caption
    @card.write("#{@time}-comp.jpg")
  end
    
  # private 
  def build_caption
    # get the flag for the pattern
    flag = Image.read("pittflag.png").first.resize(100, 12)
    canvas = Image.new(800, @card.rows) { self.background_color = "red" }
    good_caption = false
    pointsize = 50
    y_offset = 50
    working_phrase = "This is a phrase that is about 65 characters long or so I hear."
    # working_phrase = @phrase
    until good_caption == true
      text = Draw.new
      text.font_family = "impact"
      text.pointsize = pointsize
      text.gravity = NorthWestGravity
      text.stroke = "white"
      text.stroke_width = 3
      text.annotate(canvas, 0,0,10,y_offset, working_phrase){ self.fill = "white"} #_pattern = flag }
      metrics = text.get_multiline_type_metrics canvas, working_phrase 
      puts "Trying with #{metrics.width} text width, #{pointsize} pointsize, and #{y_offset} y offset."
      if metrics.width > 860 && pointsize < 70
        # too long. Add a newline.
        phrase_length = working_phrase.length
        phrase_array = working_phrase.split " "
        first_line = ""
        until first_line.length > 0.5 * phrase_length
          first_line = first_line + phrase_array.shift + " "
        end
        first_line.sub!(/ $/, "\n")
        first_line = first_line + phrase_array.join(" ")
        working_phrase = first_line
      elsif metrics.width < 760 && pointsize < 120
        # too short. Increase pointsize.
        pointsize = pointsize + 5
        y_offset = y_offset + 10
      else
        good_caption = true
        text.annotate(@card, 0, 0, 10, 50, working_phrase){ self.fill_pattern = flag }
      end
    end
  end

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
