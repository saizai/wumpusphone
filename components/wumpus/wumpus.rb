methods_for :global do
  def say text
    Dir.mkdir File.join(Dir.pwd, 'sounds') if !File.exist? File.join(Dir.pwd, 'sounds')
    dir = File.join(Dir.pwd, 'sounds')
    hash = text.to_s.hash.to_s.sub('-','x')
    filename = File.join dir, hash + '.gsm'
    if !File.exist? filename
      temp_filename = File.join dir, hash + '.aiff'
      system "say -o \"#{temp_filename}\" #{text}"
      system "sox \"#{temp_filename}\" -r 8000 -c 1 \"#{filename}\" resample -ql "
      File.delete temp_filename
    end

    play File.join(dir, hash)
  end
end

methods_for :dialplan do
  def wumpus
    Wumpus.new(self).start
  end
end

class Wumpus
  def initialize(call)
    @call = call
    @config = COMPONENTS.wumpus
    
    @current_node = -1
    @moves = 0
    
    seed_wumpus
  end

  def start
    loop do
      if wumpus_is_moving
        move_wumpus 
        kill_wumpus if @current_node == @current_wumpus_node
      end
      # TODO: actually we'd rather not play these in sequence but overlappingly; that has to be done in sox.
      # also, ideally, the hold would only be invoked after the wumpus is heard to move onto the player, one second in
      @choice = @call.input 1, :timeout => 10, :play => [wumpus_noise, current_menu].flatten
      @moves += 1 # this must not come between wumpus move and player move, for wumpus_noise to be correct
      update_state
    end
  end  
  
  def current_node
    @config['nodes'][@current_node]
  end
  
  def current_menu
    File.join(Dir.pwd, 'menus', current_node['name'])
  end
  
  def update_state
    @current_node = current_node['options'][@choice]
    hold if @current_node == @current_wumpus_node
    
  end
  
  def current_hold
    @config['holds'][rand(3)]
  end
  
  def hold
    intro = true
    key = nil
    while !phreaked(key) do
      key = nil
      if intro
        key ||= @call.interruptible_play_with_autovon File.join('Dir.pwd', 'holds', current_hold['name']) 
        intro = false
      end
      key ||= @call.interruptible_play_with_autovon File.join('Dir.pwd', 'holds', 'song_that_never_ends')
    end
    
    # Successfully phreaked. Play the reward.
    current_hold['clicks'].times { dtmf '*' }
    dtmf current_hold['dtmf']
  end
  
  # a variant of interruptible_play, this also takes the extra four DTMF tones
  def interruptible_play_with_autovon(*files)
    files.flatten.each do |file|
      result = result_digit_from response("STREAM FILE", file, "1234567890*#abcd")
      return result if result != 0.chr
    end
    nil
  end
  
  def phreaked? key
    case current_hold['name']
    when 'caller_id':
      @call.variables['callerid'] =~ /^1?684/ # extract area code
    when 'priority_override':
      key =~ /(a|b|c|d)/
    when 'insert_coin':
      key =~ /\$/ # TODO: get Asterisk to recognize coins and output them as keys 
    else
      raise 'unknown phreaking challenge'
    end
  end

  def distance(source, target)
    dist = 0
    seen = []
    fringe = [source]
    loop do
      return dist if fringe.include? target
      seen += fringe
      fringe = fringe.map{|node| @config.nodes[node]['orientation']}.flatten.reject{|node| seen.include? node}
      dist += 1
    end
  end

  def move_wumpus
    came_from = @config.nodes[@current_wumpus_node]['orientation'].index(@last_wumpus_node)
    @last_wumpus_node = @current_wumpus_node
    @current_wumpus_node = @config.nodes[@current_wumpus_node]['orientation'][(came_from + @wumpus_turn) % 3]
    @wumpus_turn = -@wumpus_turn
  end 
  
  def wumpus_is_moving
    return (@moves % 2) == 0
  end

  def seed_wumpus
    # hack to make the wumpus far from where the player is now
    @current_wumpus_node = (10 + @current_node) % 20
    @last_wumpus_node = @current_wumpus_node ^ 1
    @wumpus_turn ||= 1 # 1 or -1, indicating whether to turn left or right next
    @wumpus_hp ||= 3
  end

  # Called if the wumpus moves onto the current position
  def kill_wumpus
    @wumpus_hp -= 1
    @call.play File.join(Dir.pwd, 'wumpus', "death_#{3 - @wumpus_hp}")
    seed_wumpus
  end

  def wumpus_noise
    return [] if @wumpus_hp <= 0 # can't hear it if it's dead
    apparent_last_wumpus_node = wumpus_is_moving ? @last_wumpus_node : @current_wumpus_node
    noise = ['silence/1', 'silence/1']
    d = distance(@current_node, apparent_last_wumpus_node)
    noise[0] = File.join(Dir.pwd, 'wumpus', "crosstalk_#{3 - @wumpus_hp}_#{d}") if d <= 2
    d = distance(@current_node, @current_wumpus_node)
    noise[1] = File.join(Dir.pwd, 'wumpus', "crosstalk_#{3 - @wumpus_hp}_#{d}") if d <= 2
    return noise
  end

end
