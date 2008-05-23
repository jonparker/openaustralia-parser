#!/usr/bin/env ruby

$:.unshift "#{File.dirname(__FILE__)}/lib"

require 'mechanize_proxy'
require 'name'
require 'people'
require 'configuration'

conf = Configuration.new

agent = MechanizeProxy.new
agent.cache_subdirectory = "parse-member-links"

puts "Reading member data..."
people = People.read_csv("data/members.csv", "data/ministers.csv", "data/shadow-ministers.csv")

puts "Personal home page & Contact Details (Gov website)..."

page = agent.get('http://www.aph.gov.au/house/members/mi-alpha.asp')

xml = File.open("#{conf.members_xml_path}/websites.xml", 'w')
x = Builder::XmlMarkup.new(:target => xml, :indent => 1)
x.instruct!
x.publicwhip do
  page.links[19..-4].each do |link|
    name = Name.last_title_first(link.text.split(',')[0..1].join(','))
    person = people.find_person_by_name_current_on_date(name, Date.today)
    if person
      sub_page = agent.click(link)
      home_page_tag = sub_page.links.find{|l| l.text == "Personal Home Page"}
      
      params = {:id => person.id, :mp_contactdetails => sub_page.uri}
      params[:mp_website] = home_page_tag.uri if home_page_tag
      x.personinfo(params)
    else
      puts "WARNING: Could not find person with name #{name.full_name}"
    end
  end
end

puts "Q&A Links..."

# First get mapping between constituency name and web page
page = agent.get('http://www.abc.net.au/tv/qanda/find-your-local-mp-by-electorate.htm')
map = {}
page.links[35..183].each do |link|
  map[link.text.downcase] = page.uri + link.uri
end
# Hack to deal with "Flynn" constituency incorrectly spelled as "Flyn"
map["flynn"] = "http://www.abc.net.au/tv/qanda/mp-profiles/flyn.htm"

xml = File.open("#{conf.members_xml_path}/links-abc-qanda.xml", 'w')
x = Builder::XmlMarkup.new(:target => xml, :indent => 1)
x.instruct!
x.publicwhip do
  people.find_current_house_members.each do |member|
    short_division = member.division.downcase[0..3]
    link = map[member.division.downcase]
    throw "Couldn't lookup division #{member.division}" if link.nil?
    x.personinfo(:id => member.person.id, :mp_biography_qanda => link)
  end
end
xml.close
