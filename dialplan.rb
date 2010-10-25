adhearsion {
  # sleep(2)
  # answer
  # voicemail_main
  
  self.call.variables[:destination] = get_variable("destination")
  dial self.call.variables[:destination]
  
  # play 'ha/power-failure'  
  # play extension
  # 
  # # x = input 11, :timeout => 3.seconds
  # record {
  #   dial "SIP/16505752552@361087430", :caller_id => '12345678901'    
  # }
  # 
  # # menu 'hello-world', :timeout => 3.seconds, :tries => 3 do |link|
  # #   link.dotmf 1
  # #   
  # #   link.on_invalid { say_digits '1' }
  # #   link.on_premature_timeout { say_digits '2'}
  # #   link.on_failure { say_digits '3' }
  # # end
  # 
  # play 'goodbye'
  # hangup
  # filename = '/Users/saizai/Documents/workspace/testphoneapp/foo.aiff'
  # system 'say -o foo.aiff whee it works'
  # play filename
}

dotmf {
  dtmf '123'  
}