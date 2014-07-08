require 'colorize'

class InvalidMoveError < StandardError
end

class InputError < StandardError
end

class String
  def bg_color(row, col)
    if row.even? && col.odd?
      self.on_black
    elsif row.odd? && col.even?
      self.on_black
    else
      self
    end
  end
end

class Game
  def initialize
    @board = Board.new
    @player = :b
  end
  
  def play
    begin
      while @board.over.nil?
        player_name = @player == :r ? "Red" : "Black"
        @board.print_board
      
        puts "#{player_name}, enter a piece and a sequence of moves separated by commas (e.g. a1,ur,ul,dl,dr):"

        @player == :r ? input = get_input : input = get_ai_input(:b)
        piece = @board[[input[0], input[1]]]
        
        message = piece.valid_move_seq(input[2..-1])
        
        if message == "no error"
          piece.perform_moves!(input[2..-1])
        else
          raise InvalidMoveError.new(message)
        end
        
        @player == :r ? @player = :b : @player = :r
      end
    rescue StandardError => e
      puts e.message
      sleep(1)
      retry
    end
    
    @board.print_board
    puts "Congrats, #{@board.over}!"
  end
  
  def get_input
    input = gets.chomp.downcase.split(",")
    raise InputError.new("No moves given!") if input.length < 2
    raise InputError.new("No piece given!") if input[0].length < 2 || !("a".."h").include?(input[0][0]) || !("1".."8").include?(input[0][1])
    input = [input[0][1].to_i - 1, input[0][0].ord - "a".ord] + input[1..-1]
    
    if @board[[input[0], input[1]]]
      raise InputError.new("Not your color!") if @board[[input[0], input[1]]].color != @player
    else
      raise InputError.new("No piece there!")
    end
    
    input
  end
  
  def eval_board(board, color)
    freq = Hash.new(0)
    board.each do |pos|
      next unless board[pos]
      freq[board[pos].color] += 1
    end
    return freq[:r] - freq[:b] if color == :r
    freq[:b] - freq[:r]
  end
  
  def get_ai_input(color)
    input = []
    new_board = Board.new
    move_strengths = []
    
    @board.each do |pos|
      next unless @board[pos] && @board[pos].color == color
      [["ul"], ["ur"], ["dr"], ["dl"]].each do |dir|
        message = @board[pos].valid_move_seq(dir)

        if message == "no error"
          new_board = @board.dup[pos].perform_moves!(dir)
          move_strengths << [pos[0], pos[1], dir[0], eval_board(new_board, color)]
        else
          next
        end
        
      end
    end

    good_moves = []
    move_strengths.each{ |state| good_moves << state[0..2] if state[3] == move_strengths.map{|arr| arr[3]}.max}
    good_moves.sample
  end
  
end

class Board
  
  def initialize
    @board = Array.new(8) { Array.new(8) }
    #Piece.new([5, 5], :r, self)
    #Piece.new([6, 6], :b, self)
    setup_board
  end
  
  def setup_board
    each do |row, col|
      if row == 0 || row == 2
        Piece.new([row, col], :r, self) if col.even?
      elsif row == 1
        Piece.new([row, col], :r, self) if col.odd?
      elsif row == 5 || row == 7
        Piece.new([row, col], :b, self) if col.odd?
      elsif row == 6
        Piece.new([row, col], :b, self) if col.even?
      end
    end
  end
  
  def [](pos)
    @board[pos[0]][pos[1]]
  end
  
  def []=(pos, value)
    @board[pos[0]][pos[1]] = value
  end
  
  def each(&prc)
    @board.each_with_index do |row, row_idx|
      row.each_index do |col_idx|
        prc.call([row_idx, col_idx])
      end
    end
  end
  
  def print_board
    system "clear"
    puts "   C  H  E  C  K  E  R  S"
    each do |row, col|
      print "#{row + 1} " if col == 0
      if self[[row, col]]
        print "#{self[[row, col]].color_char.bg_color(row, col)}"
      else
        print '   '.bg_color(row, col)
      end
      puts if col == 7
    end
    puts "   A  B  C  D  E  F  G  H"
  end
  
  def dup
    new_board = Board.new
    
    each do |pos|
      if self[pos]
        Piece.new(pos, self[pos].color, new_board)
      else
        new_board[pos] = nil
      end
    end
    
    new_board
  end
  
  def over
    return "Red" if @board.flatten.reject{ |piece| piece.nil?}.all?{ |piece| piece.color == :r}
    return "Black" if @board.flatten.reject{ |piece| piece.nil?}.all?{ |piece| piece.color == :b}
    nil
  end
end

class Piece
  BLACK_DIRS = {
    "ur" => [-1, 1],
    "ul" => [-1, -1]
  }
  
  RED_DIRS = {
    "dr" => [1, 1],
    "dl" => [1, -1]
  }
    
  attr_accessor :pos
  attr_reader :color
  
  def initialize(pos, color, board)
    @pos = pos
    @color = color
    @board = board
    @board[pos] = self
    @king = false
  end
  
  def color_char
    @king ? color_char = " ♚ " : color_char = " ◉ "
    self.color == :r ? color_char.colorize(:red) : color_char
  end
  
  def valid_move?(dir, type)
    x, y = self.pos[0], self.pos[1]
    dirs = self.color == :r ? RED_DIRS : BLACK_DIRS
    dirs = BLACK_DIRS.merge(RED_DIRS) if @king
    raise InvalidMoveError.new("Invalid direction!") if !dirs.keys.include?(dir)
    
    dx, dy = dirs[dir][0], dirs[dir][1]
    
    if type == "s"
      return false if !(x + dx).between?(0, 7) || !(y + dy).between?(0, 7)
    else
      return false if !(x + dx).between?(0, 7) || !(y + dy).between?(0, 7)
      return false if !(x + dx * 2).between?(0, 7) || !(y + dy * 2).between?(0, 7)
    end
    
    true
  end
  
  def perform_slide(dir)
    x, y = self.pos[0], self.pos[1]
    dirs = self.color == :r ? RED_DIRS : BLACK_DIRS
    dirs = BLACK_DIRS.merge(RED_DIRS) if @king
    
    dx, dy = dirs[dir][0], dirs[dir][1]
    
    ending_pos = [x + dx, y + dy]
    
    return false if @board[ending_pos]
    
    @board[ending_pos] = self
    @board[self.pos] = nil
    self.pos = ending_pos
    
    true
  end
  
  def perform_jump(dir)
    x, y = self.pos[0], self.pos[1]
    dirs = self.color == :r ? RED_DIRS : BLACK_DIRS
    dirs = BLACK_DIRS.merge(RED_DIRS) if @king
    
    dx, dy = dirs[dir][0], dirs[dir][1]
    
    jump_pos = [x + dx, y + dy]
    ending_pos = [x + dx * 2, y + dy * 2]
    
    return false if !@board[jump_pos] || @board[ending_pos] || @board[jump_pos].color == self.color
    
    @board[ending_pos] = self
    @board[self.pos] = @board[jump_pos] = nil
    self.pos = ending_pos
    
    true
  end
  
  def maybe_promote
    @king = true if self.pos[0] == 0 && self.color == :b
    @king = true if self.pos[0] == 7 && self.color == :r
  end
  
  def valid_move_seq(move_sequence)
    begin
      @board.dup[self.pos].perform_moves!(move_sequence)
    rescue StandardError => e
      return e.message
    end
    "no error"
  end
  
  def perform_moves!(move_sequence)    
    if move_sequence.length == 1
      raise InvalidMoveError.new("Out of bounds!") if !valid_move?(move_sequence[0],"s")
      
      if !perform_slide(move_sequence[0])
        if !perform_jump(move_sequence[0])
          raise InvalidMoveError.new("Invalid move!")
        end
      end
      
    else
      move_sequence.each_with_index do |move, index|
        raise InvalidMoveError.new("Out of bounds!") if !valid_move?(move_sequence[index],"j")
        raise InvalidMoveError.new("Invalid move!") if !perform_jump(move_sequence[index])
      end
    end
    
    self.maybe_promote
    @board
  end
end

Game.new.play


=begin
  def forward_moves(color, pos)
    moves = []
    x, y = self.pos[0], self.pos[1]

    if color == :r
      moves << [x - 1, y + 1] if (x - 1).between?(0,7) && (y + 1).between?(0,7)
      moves << [x - 1, y - 1] if (x - 1).between?(0,7) && (y - 1).between?(0,7)
    else
      moves << [x + 1, y + 1] if (x + 1).between?(0,7) && (y + 1).between?(0,7)
      moves << [x + 1, y - 1] if (x + 1).between?(0,7) && (y - 1).between?(0,7)
    end
    
    moves
  end
    
  def moves
    moves = []
    
    if @king
      moves += forward_moves(:r, self.pos)
      moves += forward_moves(:b, self.pos)
    else
      moves += forward_moves(self.color, self.pos)
    end
    
    moves
  end
=end