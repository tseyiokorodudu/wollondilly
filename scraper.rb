require 'scraperwiki'
require 'mechanize'
require 'date'

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

agent = Mechanize.new  {|a| a.ssl_version, a.verify_mode = 'TLSv1_2'}

# params = OpenSSL::SSL::SSLContext::DEFAULT_PARAMS
# params[:ssl_version] = :TLSv1_1
# #params[:ciphers] = ['DES-CBC3-SHA']
# OpenSSL::SSL::SSLContext::DEFAULT_PARAMS = params

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
  record['council_reference'] = results.search('span[contains("Application No.")] ~ span')[i].text
  record['address']           = results.search('h4')[i].text.gsub('  ', ', ')
  record['description']       = results.search('span[contains("Type of Work")] ~ span')[i].text
  record['info_url']          = base_url
  record['comment_url']       = comment_url
  record['date_scraped']      = Date.today.to_s
  record['date_received']     = Date.strptime(results.search('span[contains("Date Lodged")] ~ span')[i].text, '%d/%m/%Y').to_s

  if (ScraperWiki.select("* from data where `council_reference`='#{record['council_reference']}'").empty? rescue true)
    puts "Saving record " + record['council_reference'] + ", " + record['address']
    # puts record
    ScraperWiki.save_sqlite(['council_reference'], record)
  else
    puts "Skipping already saved record " + record['council_reference']
  end
end
