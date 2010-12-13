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
  
  def prefix
    "#{Time.now.strftime("%Y-%m-%d %H:%M:%S %Z")} #{(@call || self.call).uniqueid}"
  end
  
  def ahn_log_with_header text
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
    
    @current_node = -1
    @moves = 0
    reset_timeout!

    @current_hold = rand(3)
    
    seed_wumpus
  end

  def start
    ahn_log_with_header 'CALL RECEIVED'
    ahn_log_with_header @call.inspect
    choice = nil
    once = true
    loop do
      ahn_log_with_header "player: #{@current_node}\twumpus: #{@current_wumpus_node}\tHP: #{@wumpus_hp}\tlast input: #{choice}"
      # TODO: actually we'd rather not play these in sequence but overlappingly; that has to be prepared in sox.
      # also, ideally, the hold would only be invoked after the wumpus is heard to move onto the player, one second in.
      # So maybe it shd be one second of crosstalk + silence, and one second of crosstalk + menu.
      choice = @call.input 1, :timeout => 15, :play => once ? wumpus_noise : current_menu 
      once = false
      timeout and redo if choice == '' # we've timed out
      timeout(:extension) and redo if !current_node['options'][choice]
      reset_timeout!
      
      @current_node = current_node['options'][choice]
      hold if @current_node == @current_wumpus_node
      update_wumpus_state
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
    @call.play File.join(Dir.pwd, 'audio', 'holds', "reward_#{@current_hold}")
    ahn_log_with_header "phreaked: #{current_hold['dtmf']}"
    @current_hold = (@current_hold + 1) % 3 # make it easy to get all three in a single call
    
    # After phreaking you don't want to be right on top of the wumpus again; move him along some.
    5.times { update_wumpus_state }
  end
  
  def phreaked? key
    case current_hold['name']
    when 'caller_id':
      @call.callerid.to_s =~ /^\+?1?684/ # extract area code
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

  def update_wumpus_state
    if @wumpus_hp > 0 and wumpus_is_moving
      move_wumpus 
      kill_wumpus if @current_node == @current_wumpus_node
    end
    @moves += 1 # coming between wumpus move and player move, as this does, wumpus_noise needs to test for the other parity
  end

  def move_wumpus
    came_from = @config['nodes'][@current_wumpus_node]['orientation'].index(@last_wumpus_node)
    @last_wumpus_node = @current_wumpus_node
    @current_wumpus_node = @config['nodes'][@current_wumpus_node]['orientation'][(came_from + @wumpus_turn) % 3]
    @wumpus_turn = -@wumpus_turn
  end 

  def wumpus_is_moving
    (@moves % 2) == 0
  end

  def wumpus_has_moved
    (@moves % 2) == 1
  end

  def seed_wumpus
    # hack to make the wumpus far from where the player is now
    @current_wumpus_node = (10 + @current_node) % 20
    @last_wumpus_node = @current_wumpus_node ^ 1
    @wumpus_turn ||= 1 # 1 or -1, indicating whether to turn left or right next
    @wumpus_hp ||= 3
    update_wumpus_state
  end

  # Called if the wumpus moves onto the current position
  def kill_wumpus
    @call.play File.join(Dir.pwd, 'audio', 'wumpus', "death_#{3 - @wumpus_hp}")
    @wumpus_hp -= 1
    seed_wumpus
  end

  def wumpus_noise
    return [] if @wumpus_hp <= 0 # can't hear it if it's dead
    oldd = 3 - distance(@current_node, wumpus_has_moved ? @last_wumpus_node : @current_wumpus_node)
    oldd = 0 if oldd < 0
    newd = 3 - distance(@current_node, @current_wumpus_node)
    newd = 0 if newd < 0
    if oldd == 0 and newd == 0
      current_menu
    else
      File.join(Dir.pwd, 'audio', 'nodes', "#{@current_node}_crosstalk_#{3 - @wumpus_hp}v#{oldd}#{newd}")      
    end
  end

end
