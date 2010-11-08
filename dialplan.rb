adhearsion {

  puts result_digit_from response("STREAM FILE", 'en/demo-echodone', "1234567890*#abcd")

  wumpus
  
  # sleep(2)
  # answer
  # voicemail_main
  
  # dtmf '147*2580369#abcd'
  
  # puts self.call.inspect
  # e.g.: <Adhearsion::Call:0x1025cdc28 @calleridname="device", @enhanced=0.0, @context="adhearsion", @io=#<TCPSocket:0x1025ce218>, @tags=[], @callingtns=0, @language="en", @type="SIP", @originating_voip_platform=:asterisk, @callingpres=0, @uniqueid="1289071205.4", @extension=8000, @tag_mutex=#<Mutex:0x1025cdac0>, @channel="SIP/adhearsion-00000004", @version="1.8.0", @callingani2=0, @accountcode="", @network=true, @dnid=8000, @query={}, @priority=1, @request=#<URI::Generic:0x1025c84a8 URL:agi://127.0.0.1>, @type_of_calling_number=:unknown, @variables={:type=>"SIP", :version=>"1.8.0", :language=>"en", :query=>{}, :rdnis=>nil, :network=>true, :context=>"adhearsion", :extension=>8000, :enhanced=>0.0, :type_of_calling_number=>:unknown, :callingani2=>0, :callingpres=>0, :callerid=>200, :dnid=>8000, :channel=>"SIP/adhearsion-00000004", :callingtns=>0, :threadid=>4640972800, :accountcode=>"", :uniqueid=>"1289071205.4", :calleridname=>"device", :request=>#<URI::Generic:0x1025c84a8 URL:agi://127.0.0.1>, :priority=>1}, @threadid=4640972800, @rdnis=nil, @callerid=200>
  
  # play 'because-paranoid'  
  # play extension
  
  # say 'text to speech engines are people too'
  
  # # x = input 11, :timeout => 3.seconds
  # record {
  #   dial "SIP/16505752552@361087430", :caller_id => '12345678901'    
  # }
  # 
  # menu 'hello-world', :timeout => 3.seconds, :tries => 3 do |link|
  #   link.dotmf 1
  #   link.star '*'
  #   
  #   link.on_invalid { play 'invalid' }
  #   link.on_premature_timeout {|str| play 'sorry'}
  #   link.on_failure { play 'goodbye'; hangup }
  # end
}
# 
# dotmf {
#   dtmf '123'  
# }
# 
# star {
#   dtmf '987'
# }