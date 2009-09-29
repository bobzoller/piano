require 'rubygems'
require 'mechanize'
require File.join(File.dirname(__FILE__), 'models')

config = YAML.load(File.read(File.join(File.dirname(__FILE__), '../', 'config', "config.yml")))
itunes_connect_config = config['itunes_connect']
local_currency = config['local_currency']

if ARGV[0]
  date = Date.parse(ARGV[0])
else
  date = Date.today - 1
end

puts "Downloading reports for #{date}"

agent = WWW::Mechanize.new 
agent.user_agent_alias = 'Mac Safari'
agent.follow_meta_refresh = true

page = agent.get("https://itunesconnect.apple.com/WebObjects/iTunesConnect.woa")
login_form = page.form_with(:name => "appleConnectForm")
login_form.field_with(:name => "theAccountName").value = itunes_connect_config["login"]
login_form.field_with(:name => "theAccountPW").value = itunes_connect_config["password"]
lobby = agent.submit(login_form)

link = lobby.link_with(:text => "Sales/Trend Reports")
itts = agent.get(link.href)

report_form = itts.form_with(:name => "frmVendorPage")
report_form.field_with(:name => "11.7").value = "Summary"
report_form.field_with(:name => "11.9").value = "Daily"
report_form.field_with(:name => "hiddenDayOrWeekSelection").value = date.strftime("%m/%d/%Y")
report_form.field_with(:name => "hiddenSubmitTypeName").value = "Preview"
report_page = agent.submit(report_form)

report_table = (report_page/"table")[4]
rows = (report_table/"tr")
(1...rows.size).each do |i|
  row = rows[i] 
  cols = (row/"td")
  
  report = nil
  country = nil
  product = nil

  next unless cols[16] && cols[10]

  product = Product.find_or_create_by_vendor_identifier(cols[16].content)
  country = Country.find_or_create_by_country_code(cols[10].content)

  report = DailyReport.create( :product_type => cols[4].content,
                      :units => cols[5].content,
                      :royalty_price => cols[6].content,
                      :customer_price => cols[8].content,
                      :currency => cols[9].content,
                      :date_of => date,
                      :product => product,
                      :country => country )


end
