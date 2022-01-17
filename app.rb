require 'sinatra'
require 'openapi_ruby_sdk_binary' # replace with new gem name************

include RubySdk # replace with new module name**************

BW_ACCOUNT_ID = ENV.fetch("BW_ACCOUNT_ID")
BW_USERNAME = ENV.fetch("BW_USERNAME")
BW_PASSWORD = ENV.fetch("BW_PASSWORD")
BW_NUMBER = ENV.fetch("BW_NUMBER")
BW_MESSAGING_APPLICATION_ID = ENV.fetch("BW_MESSAGING_APPLICATION_ID")
LOCAL_PORT = ENV.fetch("LOCAL_PORT")

set :port, LOCAL_PORT

RubySdk.configure do |config|   # replace with new module name************   # Configure HTTP basic authorization: httpBasic
    config.username = BW_USERNAME
    config.password = BW_PASSWORD
end

$api_instance_msg = RubySdk::MessagesApi.new()  # replace with new module name************

post '/callbacks/outbound/messaging/status' do  # This URL handles outbound message status callbacks.
    data = JSON.parse(request.body.read)
    case data[0]["type"] 
        when "message-sending"
            puts "message-sending type is only for MMS."
        when "message-delivered"
            puts "Your message has been handed off to the Bandwidth's MMSC network, but has not been confirmed at the downstream carrier."
        when "message-failed"
            puts "For MMS and Group Messages, you will only receive this callback if you have enabled delivery receipts on MMS."
        else
            puts "Message type does not match endpoint. This endpoint is used for message status callbacks only."
        end
    return ''
end

post '/callbacks/inbound/messaging' do  # This URL handles inbound message callbacks.
    data = JSON.parse(request.body.read)
    inbound_body = BandwidthCallbackMessage.new.build_from_hash(data[0])
    puts inbound_body.description
    if inbound_body.type == "message-received"
        puts "To: " + inbound_body.message.to[0] + "\nFrom: " + inbound_body.message.from + "\nText: " + inbound_body.message.text

        auto_reponse_message = auto_response(inbound_body.message.text)

        body = MessageRequest.new
        body.application_id = BW_MESSAGING_APPLICATION_ID
        body.to = inbound_body.message.from
        body.from = BW_NUMBER
        body.text = auto_reponse_message

        $api_instance_msg.create_message(BW_ACCOUNT_ID, body)

        puts "\nSending Auto Response\n"
        puts "To: " + inbound_body.message.from + "\nFrom: " + inbound_body.message.to[0] + "\nText: " + auto_reponse_message
    else
        puts "Message type does not match endpoint. This endpoint is used for inbound messages only.\nOutbound message status callbacks should be sent to /callbacks/outbound/messaging/status."
    end
    return ''
end

$response_map = {
    stop: "STOP: OK, you'll no longer receive messages from us.",
    quit: "QUIT: OK, you'll no longer receive messages from us.",
    help: "Valid words are: STOP, QUIT, HELP, and INFO. Reply STOP or QUIT to opt out.",
    info: "INFO: This is the test responder service. Reply STOP or QUIT to opt out.",
    default: "Please respond with a valid word. Reply HELP for help."
}

def auto_response (inbound_text)
    command = inbound_text.match(/(.\S+)/)[0].downcase.to_sym
    if $response_map.key?(command)
        map_val = $response_map[command]
    else
        map_val = $response_map[:default]
    end

    response = "[Auto Response] " + map_val
    return response
end
