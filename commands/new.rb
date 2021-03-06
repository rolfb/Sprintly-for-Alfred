require 'cgi'

QUERY = ARGV[0].to_s.strip
require_relative "../lib/sly"

begin
  sly = Sly::Interface.new
rescue Sly::ConfigFileMissingError => e
  puts Sly::WorkflowUtils.results_feed([Sly::WorkflowUtils.error_item(e)])
  exit
end

regex = /^
  (?<type>story|task|defect|test)
  (?:\s+(?<score>s|m|l|xl))?
  (?:\s+(?<title>[^\#\@]+))?
  (?<tags>(?:\s+\#[^\#\@]*\s*)+\s*)?
  (?:\@(?<assigned_to>[\w]*))?
$/ix

matches = regex.match(QUERY)

defaults = {
  status: "backlog",
  type: "task",
  title: "Preview",
  score: "~",
  tags: [],
  assigned_to: ""
}

types = ["story", "task", "defect", "test"]
scores = {s:"small", m:"medium", l:"large", xl:"extra-large"}
options = []

if matches
  item = defaults.dup
  item.each_key do |key| 
    if matches.names.include?(key.to_s) && matches[key]
      item[key] = matches[key].strip
    end
  end

  #autocomplete score
  if QUERY.match(/^#{item[:type]} ?$/i)
    options = []
    scores.each_key do |score|
      options << Sly::WorkflowUtils.autocomplete_item(scores[score].capitalize, "", "#{item[:type]} #{score} ", "images/#{item[:type]}-#{score}.png")
    end
    puts Sly::WorkflowUtils.results_feed(options)
    exit
  end

  #autocomplete person
  person_match = QUERY.match(/\@([a-z]*)$/i)
  if person_match
    people = sly.people(person_match[1])
    people.map! { |person| Sly::WorkflowUtils.autocomplete_item(person.full_name, person.email, QUERY.sub(/#{person_match[1]}$/, person.id.to_s)) }
    puts Sly::WorkflowUtils.array_to_xml(people)
    exit
  end

  unless item[:tags].empty?
    #convert "#tag1 #tag2" to [tag1, tag2]
    item[:tags] = item[:tags].strip.split(" #").map { |tag| tag.strip.sub(/^#/, "") }
  end

  #convert "@id" to Person
  item[:assigned_to] = item[:assigned_to].empty? ? nil : sly.connector.person(item[:assigned_to])

  preview_item = Sly::Item.new_typed(item)
  result = preview_item.alfred_result

  if item[:title] == defaults[:title]
    result[:autocomplete] = QUERY
    result[:valid] = "no"
  else
    result[:arg] = CGI.escape(preview_item.to_json)
  end

  options = [result]

#autocomplete type
else
  types.each do |type|
    if QUERY.empty? || type.match(/^#{QUERY.downcase}/)
      options << Sly::WorkflowUtils.autocomplete_item(type.capitalize, "", type+" ", "images/#{type}-~.png")
    end
  end
end

options = [Sly::WorkflowUtils.empty_item] if options.empty?

puts Sly::WorkflowUtils.results_feed(options)