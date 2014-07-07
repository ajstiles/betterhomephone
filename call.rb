# Load environment variables
require 'dotenv'
Dotenv.load

require 'sinatra'
require 'twilio-ruby'
require 'pony'

# Set our xml response content type for all responses
before do
  content_type "text/xml", :charset => 'utf-8'
end

# Handle POST to /answer endpoint
post '/answer' do
  response = Twilio::TwiML::Response.new do |r|
    r.Gather :numDigits => "1", :method => "POST", :action => "/record_or_connect", :timeout => "1" do
      r.Play ENV['GREETING_MP3_URL'], :loop => "1"
    end
    r.Record :action => "/record_voicemail", :method => "POST"
  end
  response.text
end

# Handle user input by either connecting to one of our cell phones or recording a voicemail
post "/record_or_connect" do
  response = Twilio::TwiML::Response.new do |r|
    if params['DialCallStatus'] == 'completed'
      r.Hangup
      return
    end

    if params[:Digits] == "1"
      r.Dial do
        r.Number ENV['CONNECT_1_NUMBER']
      end
    elsif params[:Digits] == "2"
      r.Dial do
        r.Number ENV['CONNECT_2_NUMBER']
      end
    else
      r.Record :action => "/record_voicemail", :method => "POST"
    end
  end
  response.text
end

# Twilio gives us a URL to an MP3. Build a text-email and send
# Note - the MP3 file may not be fully available at this point,
# so just email a link (rather than downloading and attaching).
def forward_voicemail(params)
  file_url = params['RecordingUrl']
  body = "You have a new voicemail from BHP:\n\n"
  body << params['RecordingUrl']
  body << "\n\n"
  body << "Number: #{params['Caller']}\n"
  body << "From: #{params['FromCity']}, #{params['FromState']} #{params['FromCountry']}\n\n"
  Pony.mail({
    :to => ENV['VOICEMAIL_TO'],
    :from => ENV['VOICEMAIL_FROM'],
    :subject => ENV['VOICEMAIL_SUBJECT'],
    :body => body,
    :via => :smtp,
    :via_options => {
      :address => ENV['SMTP_HOST'],
      :port => ENV['SMTP_PORT'],
      :user_name => ENV['SMTP_USER'],
      :password => ENV['SMTP_PASSWORD']
    }
  })
end

# Record the user voicemail and email link to us
post "/record_voicemail" do
  forward_voicemail(params)
  response = Twilio::TwiML::Response.new do |r|
    r.Say "Thank you for calling. Bye!"
    r.Hangup
  end
  response.text
end
