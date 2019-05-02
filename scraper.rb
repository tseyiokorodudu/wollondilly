require 'scraperwiki'
require 'mechanize'
require 'date'

class Hash
  def has_blank?
    self.values.any?{|v| v.nil? || v.length == 0}
  end
end

base_url = "https://ecouncil.wollondilly.nsw.gov.au/eServeDAEnq.htm"
comment_url = "mailto:council@wollondilly.nsw.gov.au"

time = Time.new

case ENV['MORPH_PERIOD']
  when 'lastmonth'
    dateFrom = (Date.new(time.year, time.month, 1) << 1).strftime('%d/%m/%Y')
    dateTo   = (Date.new(time.year, time.month, 1)-1).strftime('%d/%m/%Y')
  when 'thismonth'
    dateFrom = Date.new(time.year, time.month, 1).strftime('%d/%m/%Y')
    dateTo   = Date.new(time.year, time.month, -1).strftime('%d/%m/%Y')
  else
    dateFrom = (Date.new(time.year, time.month, time.day)-7).strftime('%d/%m/%Y')
    dateTo   = Date.new(time.year, time.month, time.day).strftime('%d/%m/%Y')
end

puts "Scraping from " + dateFrom + " to " + dateTo + ", changable via MORPH_PERIOD variable"

agent = Mechanize.new
agent.verify_mode = OpenSSL::SSL::VERIFY_NONE
basepage = agent.get(base_url)
datepage = basepage.iframes.first.click

formpage = datepage.form_with(:name => 'daEnquiryForm') do |f|
  f.dateFrom = dateFrom
  f.dateTo   = dateTo
end.click_button

results = formpage.at('div.bodypanel ~ div')

count = results.search("h4").size - 1
for i in 0..count
  record = {}
  record['council_reference'] = results.search('span[contains("Application No.")] ~ span')[i].text rescue nil
  record['address']           = results.search('h4')[i].text.gsub('  ', ', ') rescue nil
  record['description']       = results.search('span[contains("Type of Work")] ~ span')[i].text rescue nil
  record['info_url']          = base_url
  record['comment_url']       = comment_url
  record['date_scraped']      = Date.today.to_s
  record['date_received']     = Date.strptime(results.search('span[contains("Date Lodged")] ~ span')[i].text, '%d/%m/%Y').to_s rescue nil

  unless record.has_blank?
    puts "Saving record " + record['council_reference'] + ", " + record['address']
#       puts record
    ScraperWiki.save_sqlite(['council_reference'], record)
  else
    puts "Something not right here: #{record}"
  end
end
