require 'nokogiri'
require 'open-uri'

class LMCScraper
  def self.find_pdfs(url="http://www.lincoln.ne.gov/city/attorn/lmc/contents.htm")
    html = Nokogiri::HTML.parse(open(url).read)
    links = []
    base_url = self.strip_filename(url)
    html.css('pre > a').each do |link|
      links.push(base_url + "/" + link['href'])
    end
    return links
  end

  private

  def self.strip_filename(url)
    protocol = url.split("://").first
    arr = url.split("://").last.split("/")
    arr.pop
    return protocol + "://" + arr.join("/")
  end

end

puts LMCScraper.find_pdfs.join("\n")
