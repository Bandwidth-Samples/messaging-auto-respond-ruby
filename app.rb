require 'sinatra'
require 'bandwidth-sdk'

begin
  BW_ACCOUNT_ID = ENV.fetch('BW_ACCOUNT_ID')
  BW_USERNAME = ENV.fetch('BW_USERNAME')
  BW_PASSWORD = ENV.fetch('BW_PASSWORD')
  BW_NUMBER = ENV.fetch('BW_NUMBER')
  BW_MESSAGING_APPLICATION_ID = ENV.fetch('BW_MESSAGING_APPLICATION_ID')
  LOCAL_PORT = ENV.fetch('LOCAL_PORT')
rescue StandardError
  puts 'Please set the environmental variables defined in the README'
  exit(-1)
end

set :port, LOCAL_PORT

Bandwidth.configure do |config| # Configure Basic Auth
  config.username = BW_USERNAME
  config.password = BW_PASSWORD
end

post '/callbacks/inbound/messaging' do # This URL handles inbound message callbacks.
  data = JSON.parse(request.body.read)
  inbound_body = Bandwidth::InboundMessageCallback.build_from_hash(data[0])
  puts inbound_body.description
  if inbound_body.type == 'message-received'
    puts "To: #{inbound_body.message.to[0]}\nFrom: #{inbound_body.message.from}\nText: #{inbound_body.message.text}"

    auto_reponse_message = auto_response(inbound_body.message.text)

    body = Bandwidth::MessageRequest.new(
      application_id: BW_MESSAGING_APPLICATION_ID,
      to: [inbound_body.message.from],
      from: BW_NUMBER,
      text: auto_reponse_message
    )

    messaging_api_instance = Bandwidth::MessagesApi.new
    messaging_api_instance.create_message(BW_ACCOUNT_ID, body)

    puts "\nSending Auto Response\n"
    puts "To: #{inbound_body.message.from}\nFrom: #{inbound_body.message.to[0]}\nText: #{auto_reponse_message}"
  else
    puts 'Message type does not match endpoint. This endpoint is used for inbound messages only.'
    puts 'Outbound message status callbacks should be sent to /callbacks/outbound/messaging/status.'
  end
end

post '/callbacks/outbound/messaging/status' do # This URL handles outbound message status callbacks.
  data = JSON.parse(request.body.read)
  case data[0]['type']
  when 'message-sending'
    puts 'message-sending type is only for MMS.'
  when 'message-delivered'
    puts "Your message has been handed off to the Bandwidth's MMSC network, but has not been confirmed at the downstream carrier."
  when 'message-failed'
    puts 'For MMS and Group Messages, you will only receive this callback if you have enabled delivery receipts on MMS.'
  else
    puts 'Message type does not match endpoint. This endpoint is used for message status callbacks only.'
  end
end

def auto_response(inbound_text)
  command = inbound_text.match(/(.\S+)/)[0].downcase.to_sym

  response_map = {
    stop: "STOP: OK, you'll no longer receive messages from us.",
    quit: "QUIT: OK, you'll no longer receive messages from us.",
    help: 'Valid words are: STOP, QUIT, HELP, and INFO. Reply STOP or QUIT to opt out.',
    info: 'INFO: This is the test responder service. Reply STOP or QUIT to opt out.',
    default: 'Please respond with a valid word. Reply HELP for help.'
  }

  map_val = response_map.key?(command) ? response_map[command] : response_map[:default]

  "[Auto Response] #{map_val}"
end
