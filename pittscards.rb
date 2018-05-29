require 'rmagick'
require 'twitter'
require 'yaml'
require 'open-uri'
require 'httparty'
require 'nokogiri'

class Pittscard
  include Magick

  def initialize
    # load in and set configurations
    set_configs
  end

  def tweet
    # generate a pittscard and tweet it as a media attachment
    create_pittscard
    @client.update_with_media @tweet, File.new('card.jpg')
  end

  def create_pittscard
    # generate the text
    create_tweet
    # generate the image
    create_image
  end

  def create_tweet
    # start up twitter
    start_client
    # establish the phrase for the bot
    set_phrase
    @tweet = @phrase
  end

  def create_image
    # get the saved image of Pittsburgh
    @card = Image.read(File.join("images", grab_image_of_pittsburgh)).first
    # resize it to 800px wide
    @card = @card.resize(800, (800 * @card.rows) / @card.columns)
    # darken
    @card = @card.level(-QuantumRange * 0.25, Magick::QuantumRange * 1.25, 1.0)
    build_caption
    @card.write("card.jpg")
  end
    
  # private 
  def build_caption
    # get the flag for the pattern
    flag = Image.read("pittflag.png").first
    # start a fake image just to size the text
    canvas = Image.new(800, @card.rows) { self.background_color = "red" }
    good_caption = false
    pointsize = 50
    y_offset = 20
    working_phrase = @phrase
    # iterate with different font sizes and adding line breaks until
    # everything fits nicely.
    until good_caption == true
      text = Draw.new
      # Choose Impact font either from the system or locally.
      if File.file? "Impact.ttf"
        text.font = "Impact.ttf"
      else
        text.font_family = "impact"
      end
      # set the various text parameters
      text.font_weight = BoldWeight
      text.pointsize = pointsize
      text.gravity = NorthWestGravity
      text.stroke = "white"
      text.stroke_width = 3
      text.interline_spacing = 0
      text.annotate(canvas, 0,0,10,y_offset, working_phrase){ self.fill = "white" }
      metrics = text.get_multiline_type_metrics canvas, working_phrase 
      if metrics.width > 790 && pointsize < 70
        # too long. Add a newline.
        phrase_length = working_phrase.length
        phrase_array = working_phrase.split " "
        first_line = ""
        # get to about the halfway point
        until first_line.length > 0.5 * phrase_length
          first_line = first_line + phrase_array.shift + " "
        end
        # Add a newline
        first_line.sub!(/ $/, "\n")
        first_line = first_line + phrase_array.join(" ")
        working_phrase = first_line
      elsif metrics.width < 740 && pointsize < 120
        # too short. Increase pointsize.
        pointsize = pointsize + 5
        y_offset = y_offset + 5
      else
        # we've got a good caption, so add it to the real image.
        good_caption = true
        text.annotate(@card, 0, 0, 10, y_offset, working_phrase){ self.fill_pattern = flag }
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
    @client.search('"Pittsburgh is"', { result_type: "recent" }).map{ |tweet| tweet.full_text }
    # # don't actually search twitter. Use a local file of phrases.
    # results = []
    # File.readlines("text.txt").each { |f| results << f.strip }
    # results
  end

  def grab_image_of_pittsburgh
    # Pull 500 images from Wikipedia associated w/ Pittsburgh
    # and filter out the ones end in "svg" or "tif" and the ones
    # that have "logo" in their names. Those will be less funny.
    list_of_pictures = JSON.parse(HTTParty.get("https://en.wikipedia.org/w/api.php?action=opensearch&format=json&namespace=6&search=pittsburgh&limit=500").body).last.select{|url| url !~ /(svg|tif)$/i}.select{|url| url !~ /logo/i}
    # Pick one of the remaining 450 or so images and download it.
    photo_url = get_photo_from_wiki(list_of_pictures.sample)
    extension = photo_url.match(/\w*$/)[0]
    filename = "orig-pittsburgh-#{Time.now.to_i}.#{extension}"
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

# Run the thing.
card = Pittscard.new
card.tweet
