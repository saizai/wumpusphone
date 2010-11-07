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
  def start_wumpus
    Wumpus.new(self).start
  end
end

class Wumpus
  def initialize(call)
    @call = call
    config = COMPONENTS.wumpus
    
    @current_node = -1
    @current_wumpus_node 
    @last_wumpus_node 
    @moves = 0
  end
  
  def start
    loop do
      @choice = @call.input 1, :timeout => 10, :play => [wumpus_noise, current_menu].flatten
      @moves += 1
      move_wumpus if (@moves % 2) == 0
      
    end
  end  
end
