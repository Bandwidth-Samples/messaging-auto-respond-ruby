require 'sinatra'
require 'bandwidth-sdk'

begin
  BW_ACCOUNT_ID = ENV.fetch('BW_ACCOUNT_ID')
  BW_CLIENT_ID = ENV.fetch('BW_CLIENT_ID')
  BW_CLIENT_SECRET = ENV.fetch('BW_CLIENT_SECRET')
  BW_MESSAGING_APPLICATION_ID = ENV.fetch('BW_MESSAGING_APPLICATION_ID')
  BW_NUMBER = ENV.fetch('BW_NUMBER')
  LOCAL_PORT = Integer(ENV.fetch('LOCAL_PORT'))
rescue StandardError
  puts 'Please set the environmental variables defined in the README'
  exit(-1)
end

set :port, LOCAL_PORT
set :host_authorization, permitted_hosts: []

Bandwidth.configure do |config|
  config.client_id = BW_CLIENT_ID
  config.client_secret = BW_CLIENT_SECRET
end

STATUS_MESSAGES = {
  'message-sending' => 'message-sending type is only for MMS.',
  'message-delivered' => "Your message has been handed off to the Bandwidth's MMSC network, but has not been confirmed at the downstream carrier.",
  'message-failed' => 'For MMS and Group Messages, you will only receive this callback if you have enabled delivery receipts on MMS.'
}.freeze

REPLIES = {
  'stop' => "STOP: OK, you'll no longer receive messages from us.",
  'quit' => "QUIT: OK, you'll no longer receive messages from us.",
  'help' => 'Valid words are: STOP, QUIT, HELP, and INFO. Reply STOP or QUIT to opt out.',
  'info' => 'INFO: This is the test responder service. Reply STOP or QUIT to opt out.'
}.freeze
DEFAULT_REPLY = 'Please respond with a valid word. Reply HELP for help.'.freeze

def parse_callbacks
  callbacks = JSON.parse(request.body.read)
  halt 400 unless callbacks.is_a?(Array) && callbacks.all? { |callback| callback.is_a?(Hash) }
  callbacks
rescue JSON::ParserError
  halt 400
end

def send_reply(to, text)
  message_request = Bandwidth::MessageRequest.new(
    application_id: BW_MESSAGING_APPLICATION_ID,
    to: [to],
    from: BW_NUMBER,
    text: text
  )
  message = Bandwidth::MessagesApi.new.create_message(BW_ACCOUNT_ID, message_request)
  puts "Sent reply #{message.id}\nTo: #{to}\nText: #{text}"
rescue StandardError => e
  warn "Failed to send reply: #{e.message}"
end

post '/callbacks/outbound/messaging/status' do # This URL handles outbound message status callbacks.
  callbacks = parse_callbacks
  halt 400 unless callbacks.all? { |callback| STATUS_MESSAGES.key?(callback['type']) }

  callbacks.each { |callback| puts STATUS_MESSAGES[callback['type']] }
  status 204
end

post '/callbacks/inbound/messaging' do # This URL handles inbound message callbacks.
  callbacks = parse_callbacks
  halt 400 unless callbacks.all? { |callback| callback['type'] == 'message-received' }

  callbacks.each do |callback|
    message = callback['message']
    puts "#{callback['description']}\nTo: #{message['to'][0]}\nFrom: #{message['from']}\nText: #{message['text']}"
    send_reply(message['from'], REPLIES.fetch(message['text'].to_s.strip.downcase, DEFAULT_REPLY))
  end
  status 204
end
