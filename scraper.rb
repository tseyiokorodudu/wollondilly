require "mechanize"
require "json"
require "scraperwiki"

def parse_date(s)
  if s.strip == ""
    nil
  else
    Date.strptime(s, "%d/%m/%Y")
  end
end

root_url = "https://tracking.wollondilly.nsw.gov.au"
url = "#{root_url}/api/app"

agent = Mechanize.new
page = agent.get(url)

result = JSON.parse(page.body)

result.each do |a|
  date_received = parse_date(a["rec_dte"])
  if date_received >= Date.today - 30
    record = {
      "council_reference" => a["fmt_acc2"],
      "address" => a["prm_adr"] + ", NSW",
      "description" => a["precis"].strip,
      "info_url" => "#{root_url}/detail/#{a['fmt_acc']}",
      "date_scraped" => Date.today.to_s,
      "date_received" => date_received.to_s,
      "on_notice_from" => parse_date(a["not_opn_dte"]),
      "on_notice_to" => parse_date(a["not_clo_dte"]),
      "lat" => a["lat"],
      "lng" => a["lon"]
    }
    puts "Storing #{record["council_reference"]} - #{record["address"]}"
    ScraperWiki.save_sqlite(["council_reference"], record)
  end
end
