require 'nokogiri'
require 'open-uri'
require 'tmpdir'
require 'colorize'
require 'json'

class LMCParser
  def go
    Dir.glob('data/*.pdf').each {|pdf|
      base = File.basename(pdf, File.extname(pdf))
      path = File.expand_path(base)
      infile = 'data/' + base + '.pdf'
      outfile = 'data/' + base + '.json'
      
      File.open(outfile, 'w+') {|f|
        f.write(LMCParser.parse(infile).to_json)
      }
    }
  end
  
  def self.parse(pdf_filename)
    text = []
    Dir.mktmpdir {|dir|
      xml_filename = File.join(dir, 'temp.xml')
      output = `pdftohtml -c -i -noframes -xml "#{pdf_filename}" "#{xml_filename}"`
      xml = Nokogiri::XML.parse(File.read(xml_filename))
      text = xml.css('page > text').to_a
    }
    return self.parse_xml(text)
  end

  private

  def self.parse_ord_number(str)
    hsh = {}
    arr = str.split('.')
    hsh[:title] = arr[0].strip.gsub(/^0+/,'')
    hsh[:section] = arr[1].strip.gsub(/^0+/,'')
    hsh[:sub_section] = arr[2].strip.gsub(/^0+/,'')
    return hsh
  end

  def self.parse_ord(text, range)
    ordinance = {}
    begin
      ordinance[:number] = parse_ord_number(text[range.first - 1].children.first.text)
      ordinance[:name] = text[range.first].children.first.text.strip
    rescue
      line = text[range.first].children.first.text.strip.split(" ")
      ordinance[:number] = parse_ord_number(line.delete_at(0))
      ordinance[:name] = line.join(" ")
    end
    ordinance[:id] = ordinance[:number].values.join('.')
    ordinance[:text] = ""
    start_num = range.first + 1
    end_num = range.last
    (start_num..end_num).each do |idx|
      ordinance[:text] += (text[idx].text.strip)
      if(idx != end_num)
        if(text[idx].attr('top') != text[idx-1].attr('top'))
          ordinance[:text] += "\n"
        else
          ordinance[:text] += " "
        end
      end
    end
    ordinance[:text].strip!
    return ordinance
  end

  def self.parse_xml(text)
    start = 1
    last = text.count - 2
    beginning = 0
    ord_lines = []

    # simple two-pass parser

    # pass 1, find each ordinance
    (start..last).each do |idx|
      unless(text[idx].children.count > 0)
        next
      end
      # lookahead
      unless(text[idx + 1])
        next
      end
      unless(text[idx + 1].children.count > 0)
        next
      end

      # can we merge the current line with the previous?
      if(text[idx].attr('top') == text[idx - 1].attr('top') && text[idx].children.first.name == text[idx-1].children.first.name)
        # try to catch cases where the section header is split into two elements
        str = text[idx-1].children.first.text + " " + text[idx].children.first.text
      else
        str = text[idx].children.first.text
      end

      # true if the string contains anything that looks like num.num.num
      contains_ordinance_number = !!str.gsub(" ","").match(/\d+\.\d+\.\d+/)

      # true if heading doesn't start with "section"
      is_not_subsection = !str.downcase.match(/^section/)

      # current line is first ordinance number?
      is_aligned = text[idx].attr('left') == "108" || text[idx-1].attr('left') == "108"
      is_ord = (text[idx].children.first.name == "b" && text[idx + 1].children.first.name == "text")

      if((is_aligned && is_ord && contains_ordinance_number && is_not_subsection) || idx == last)
        if(beginning != 0)
          ord_lines.push([beginning, (idx != last ? (idx - 1) : (text.count - 1))])
        end
        beginning = idx
      end
    end

    # pass 2, parse each ordinance
    ordinances = []
    ord_lines.each do |section|
      ordinances.push(parse_ord(text, section))
    end
    return ordinances
  end
end

LMCParser.new.go
