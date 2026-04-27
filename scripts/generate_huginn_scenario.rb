#!/usr/bin/env ruby

require 'digest'
require 'json'
require 'time'
require 'yaml'

ROOT = File.expand_path('..', __dir__)
TOPICS_FILE = File.join(ROOT, 'config', 'topics.yaml')
OUTPUT_FILE = File.join(ROOT, 'huginn', 'scenarios', 'ai-news-generated.json')
RSSHUB_INTERNAL_BASE = ENV.fetch('RSSHUB_INTERNAL_BASE', 'http://rsshub:1200')
DEFAULT_SCHEDULE = ENV.fetch('HUGINN_RSS_SCHEDULE', 'every_30m')
DEFAULT_KEEP_EVENTS_FOR = ENV.fetch('HUGINN_KEEP_EVENTS_FOR', '604800').to_i
DEFAULT_EXPECTED_UPDATE_PERIOD = ENV.fetch('HUGINN_EXPECTED_UPDATE_PERIOD_IN_DAYS', '1')
DEFAULT_EXPECTED_RECEIVE_PERIOD = ENV.fetch('HUGINN_EXPECTED_RECEIVE_PERIOD_IN_DAYS', '2')

def deterministic_guid(*parts)
  Digest::MD5.hexdigest(parts.join(':'))
end

def rss_url(route)
  normalized = route.start_with?('/') ? route : "/#{route}"
  "#{RSSHUB_INTERNAL_BASE}#{normalized}"
end

def regex_for(topic)
  positive_terms = Array(topic['keywords']).map { |keyword| Regexp.escape(keyword) }
  exclude_terms = Array(topic['exclude_keywords']).map { |keyword| Regexp.escape(keyword) }

  positive_pattern = positive_terms.empty? ? '.*' : "(?:#{positive_terms.join('|')})"
  return ".*#{positive_pattern}.*" if exclude_terms.empty?

  "^(?!.*(?:#{exclude_terms.join('|')})).*#{positive_pattern}.*$"
end

def topic_trigger_agent(topic)
  {
    'type' => 'Agents::TriggerAgent',
    'name' => "#{topic['name']} Topic Filter",
    'disabled' => false,
    'guid' => deterministic_guid('trigger', topic['id']),
    'options' => {
      'expected_receive_period_in_days' => DEFAULT_EXPECTED_RECEIVE_PERIOD,
      'keep_event' => 'true',
      'rules' => [
        {
          'type' => 'regex',
          'value' => regex_for(topic),
          'path' => 'title'
        }
      ],
      'message' => '{{title}}'
    },
    'keep_events_for' => DEFAULT_KEEP_EVENTS_FOR,
    'propagate_immediately' => true
  }
end

def rss_agent(topic, route, index)
  route_name = route.sub(%r{^/}, '')
  {
    'type' => 'Agents::RssAgent',
    'name' => "#{topic['name']} - #{route_name}",
    'disabled' => false,
    'guid' => deterministic_guid('rss', topic['id'], route, index),
    'options' => {
      'expected_update_period_in_days' => DEFAULT_EXPECTED_UPDATE_PERIOD,
      'clean' => 'false',
      'url' => rss_url(route)
    },
    'schedule' => DEFAULT_SCHEDULE,
    'keep_events_for' => DEFAULT_KEEP_EVENTS_FOR
  }
end

topics_data = YAML.load_file(TOPICS_FILE)
topics = topics_data.fetch('topics')

agents = []
links = []

topics.each do |topic|
  trigger_index = agents.length
  agents << topic_trigger_agent(topic)

  Array(topic['rsshub_routes']).each_with_index do |route, route_index|
    rss_index = agents.length
    agents << rss_agent(topic, route, route_index)
    links << {
      'source' => rss_index,
      'receiver' => trigger_index
    }
  end
end

scenario = {
  'schema_version' => 1,
  'name' => 'ai-news generated',
  'description' => 'Generated from config/topics.yaml',
  'source_url' => false,
  'guid' => deterministic_guid('scenario', 'ai-news-generated'),
  'tag_fg_color' => '#ffffff',
  'tag_bg_color' => '#5bc0de',
  'icon' => 'gear',
  'exported_at' => Time.now.utc.iso8601,
  'agents' => agents,
  'links' => links,
  'control_links' => []
}

File.write(OUTPUT_FILE, JSON.pretty_generate(scenario) + "\n")
puts "Generated #{OUTPUT_FILE}"
