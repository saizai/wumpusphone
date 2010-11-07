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
    reset
    
    @current_node = -1
    
  end
  
  def start
    loop do
      say_number
      collect_attempt
      verify_attempt
    end
  end

  def random_number
    rand(10).to_s
  end

  def update_number
    @number << random_number
  end

  def say_number
    update_number
    @call.say_digits @number
  end

  def collect_attempt
    @attempt = @call.input @number.length
  end

  def verify_attempt
    if attempt_correct? 
      @call.play 'good'
    else
      @call.play %W[#{@number.length-1} times wrong-try-again-smarty]
      reset
    end
  end

  def attempt_correct?
    @attempt == @number
  end
  
  def reset
    @attempt, @number = '', ''
  end
  
end
