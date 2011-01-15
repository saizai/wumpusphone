methods_for :global do
  def say text
    Dir.mkdir File.join(Dir.pwd, 'sounds') if !File.exist? File.join(Dir.pwd, 'sounds')
    dir = File.join(Dir.pwd, 'sounds')
    hash = text.to_s.hash.to_s.sub('-','x')
    filename = File.join dir, hash + '.gsm'
    if !File.exist? filename
      temp_filename = File.join dir, hash + '.aiff'
      system "say -o \"#{temp_filename}\" #{text}" # OS X specific, of course
      system "sox \"#{temp_filename}\" -r 8000 -c 1 \"#{filename}\" resample -ql "
      File.delete temp_filename
    end

    play File.join(dir, hash)
  end
  
  # OMG what a kludge. But it gets the job done quickly, as we don't have time to figure out the proper way
  def calls_list(call = nil)
    $CALLS_LIST ||= {}
    
    if call
      $CALLS_LIST[call.channel] ||= {}
      $CALLS_LIST[call.channel][:calls] ||= {}
      # not thread-safe at all or anything. not even Correct. HACK.
      $CALLS_LIST[call.channel][:calls][@start_time.strftime("%Y-%m-%d %H:%M:%S")] = (Time.now - @start_time)
      $CALLS_LIST[call.channel][:duration] = $CALLS_LIST[call.channel][:calls].values.inject( 0 ) { |sum,x| sum+x };
    end
    
    filename = File.join(Dir.pwd, 'calls_list.html')
    callsfile = File.open(filename, 'w')
    callsfile << <<-END
    CALLS:<br/>
    # unique callers (ish): #{"%-3d" % $CALLS_LIST.count}<br/>
    total call time: #{"%-3.1f" % ($CALLS_LIST.values.map{|x| x[:duration]}.inject( 0 ) { |sum,x| sum+x } / 60.0)} minutes<br/>
    details #{$CALLS_LIST.inspect}"
    END
    callsfile.close
    
    $CALLS_LIST
  end
    
  def prefix
    "#{Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")} #{Adhearsion.active_calls.size} #{"%-40s" % (@call || self.call).channel} #{"%-3.1f" % ((Time.now - @start_time) / 60.0) rescue nil}"
  end
  
  def ahn_log_with_header text
    calls = calls_list(@call || self.call)
    # 1st number is # of unique callers (though this is very poorly aggregated); 2nd is total call duration
    ahn_log "CALLS: #{"%-3d" % calls.count} #{"%-3.1f" % (calls.values.map{|x| x[:duration]}.inject( 0 ) { |sum,x| sum+x } / 60.0)} #{calls.inspect}"
    ahn_log "#{prefix}\t#{text}"
  end
end

methods_for :dialplan do
  def wumpus
    Wumpus.new(self).start
  end

  # a variant of interruptible_play, this also takes the extra four DTMF tones and the coin tone
  def interruptible_play_with_autovon(*args)
    options = args.last.kind_of?(Hash) ? args.pop : {}
    args.flatten.each do |file|
      result = result_digit_from response("STREAM FILE", file, options[:digits] || "1234567890*#ABCD$")
      return result if result != 0.chr
    end
    nil
  end
end

class Wumpus
  def initialize(call)
    @call = call
    @config = COMPONENTS.wumpus
    
    @start_time = Time.now
    
    @current_node = -1
    @shooting = false
    @moves = 0
    reset_timeout!

    @current_hold = rand(3)
    
    seed_wumpus
  end

  def start
    ahn_log_with_header 'CALL RECEIVED'
    ahn_log_with_header @call.inspect

    if american_samoa? @call.callerid
      ahn_log_with_header "caller ID OK"
      @call.play File.join(Dir.pwd, 'audio', 'holds', 'caller_id_ok') 
      @call.play File.join(Dir.pwd, 'audio', 'holds', "reward0")
    end

    choice = nil
    once = true
    loop do
      @call.input 1, :timeout => 1 # kluge: throw out one second of input, so as not to overinterpret duplicates
      ahn_log_with_header "player: #{@current_node}\twumpus: #{@current_wumpus_node}\tHP: #{@wumpus_hp}\tlast input: #{choice}"
      choice = @call.input 1, :timeout => 15, :play => once ? wumpus_noise : current_menu 
      once = false
      timeout and redo if choice == '' # we've timed out
      redo if choice == '0' 
      timeout(:extension) and redo if !current_node['options'][choice] and choice != '#'
      reset_timeout!
      
      @current_node = current_node['options'][choice] if choice != '#'
      if @wumpus_hp > 0
        if @current_node == @current_wumpus_node and @shooting 
          kill_wumpus
        elsif (@current_node == @current_wumpus_node) ^ @shooting
          hold
        end
      end
      @shooting = (choice == '#')
      once = true
    end
  end  
  
  def current_node
    @config['nodes'][@current_node]
  end
  
  def current_menu
    File.join(Dir.pwd, 'audio', 'nodes', @current_node.to_s)
  end
  
  def no_extension
    @call.play File.join(Dir.pwd, 'audio', 'errors', 'no_such_extension')
  end
  
  def reset_timeout!
    @timeouts_left = 3
  end
  
  def timeout type = :timeout
    @timeouts_left -= 1
    if @timeouts_left <= 0 or type == :fatal
      @call.play File.join(Dir.pwd, 'audio', 'errors', 'fatal_timeout')
      ahn_log_with_header "timeout -- hanging up"
      @call.hangup
    elsif type == :extension
      ahn_log_with_header "failed extension"
      @call.play File.join(Dir.pwd, 'audio', 'errors', 'no_such_extension')      
    else
      ahn_log_with_header "timeout"
      @call.play File.join(Dir.pwd, 'audio', 'errors', 'timeout')
    end
  end
  
  def current_hold
    @config['holds'][@current_hold]
  end
  
  def hold
    return unless @wumpus_hp > 0

    intro = true
    key = nil
    verses_left = 5 # TODO: adjust this according to the length of the eventual hold music.  (I'm lazy.)
    ahn_log_with_header "hold #{verses_left} #{current_hold['name']}, CID #{@call.callerid}"
    while !phreaked?(key) do
      key = @call.interruptible_play_with_autovon File.join(Dir.pwd, 'audio', 'holds', (intro ? current_hold['name'] : 'music')), :digits => current_hold['escape_digits']
      ahn_log_with_header "hold #{verses_left} input: #{key}"
      verses_left -= 1
      timeout(:fatal) if verses_left <= 0
      intro = false
    end
    
    if current_hold['name'] == 'caller_id'
      ahn_log_with_header "caller ID OK"
      @call.play File.join(Dir.pwd, 'audio', 'holds', 'caller_id_ok') 
    end
    
    # Successfully phreaked. Play the reward.
    @call.play File.join(Dir.pwd, 'audio', 'holds', "reward#{@current_hold}")
    ahn_log_with_header "phreaked: #{current_hold['dtmf']}"
    @current_hold = (@current_hold + 1) % 3 # make it easy to get all three in a single call
    
    # After phreaking you don't want to be right on top of the wumpus again; move him.
    seed_wumpus
  end

  def american_samoa? number
    # deny callerids that are too long, 'cause they're widget uuids, and those might accidentally match /^1?684/
    number.to_s =~ /^\+?1?684/ and number.to_s.length < 32
  end
  
  def phreaked? key
    case current_hold['name']
    when 'caller_id':
      american_samoa? @call.callerid # extract area code
    when 'priority_override', 'insert_coin':
      key # we've already gotten the correct digit, if we're breaking interruptible_play
    else
      raise 'unknown phreaking challenge'
    end
  end
  
  def distance(source, target)
    dist = 0
    seen = []
    fringe = [source]
    loop do
      return 1.0/0 if fringe.empty? # unconnected points are at distance +infinity
      return dist if fringe.include? target
      seen += fringe
      fringe = fringe.map{|node| @config['nodes'][node]['orientation'] || []}.flatten.reject{|node| seen.include? node}
      dist += 1
    end
  end

  def seed_wumpus
    # don't put the wumpus on or adjacent to where the player is now.  otherwise randomise
    nearest_real_node = @current_node == -1 ? 0 : @current_node
    nodes_to_be_avoided = ([nearest_real_node] + @config['nodes'][nearest_real_node]['options'].values).sort!
    @current_wumpus_node = rand(20 - 4)
    nodes_to_be_avoided.each { |n| @current_wumpus_node += 1 if @current_wumpus_node >= n }
    @wumpus_hp ||= 3
  end

  # Called if the wumpus is successfully shot
  def kill_wumpus
    @call.play File.join(Dir.pwd, 'audio', 'wumpus', "death_#{3 - @wumpus_hp}")
    @wumpus_hp -= 1
    seed_wumpus
  end

  def wumpus_noise
    return current_menu if @wumpus_hp <= 0 # can't hear it if it's dead
    newd = 3 - distance(@current_node, @current_wumpus_node)
    newd = 0 if newd < 0
    if newd == 0
      current_menu
    else
      File.join(Dir.pwd, 'audio', 'nodes', "#{@current_node}_crosstalk_#{3 - @wumpus_hp}v#{newd}#{newd}")      
    end
  end

end
