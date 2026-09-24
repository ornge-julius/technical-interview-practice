class TicTacToeEngine
  DIRECTIONS = [[0, 1], [1, 0], [1, 1], [1, -1]].freeze

  def initialize(size: 3, win_length: nil)
    @size = size
    @win_length = win_length || size
    reset
  end

  def check_winner(board)
    size = board.length

    (0...size).each do |r|
      (0...size).each do |c|
        player = board[r][c]
        next if player.nil?

        DIRECTIONS.each do |dr, dc|
          count = 1
          rr, cc = r + dr, c + dc
          while rr.between?(0, size - 1) && cc.between?(0, size - 1) && board[rr][cc] == player
            count += 1
            rr += dr
            cc += dc
          end
          return player if count >= @win_length
        end
      end
    end

    nil
  end

  def make_move(row, col, player)
    unless row.between?(0, @size - 1) && col.between?(0, @size - 1)
      raise ArgumentError, "position (#{row}, #{col}) is out of bounds"
    end
    raise ArgumentError, "cell (#{row}, #{col}) is already occupied" unless @board[row][col].nil?

    @board[row][col] = player
    winning_move?(row, col, player) ? player : nil
  end

  def get_board
    @board.map(&:dup)
  end

  def reset
    @board = Array.new(@size) { Array.new(@size) }
  end

  private

  def winning_move?(row, col, player)
    DIRECTIONS.any? do |dr, dc|
      count = 1 + count_direction(row, col, dr, dc, player) + count_direction(row, col, -dr, -dc, player)
      count >= @win_length
    end
  end

  def count_direction(row, col, dr, dc, player)
    count = 0
    r, c = row + dr, col + dc
    while r.between?(0, @size - 1) && c.between?(0, @size - 1) && @board[r][c] == player
      count += 1
      r += dr
      c += dc
    end
    count
  end
end
