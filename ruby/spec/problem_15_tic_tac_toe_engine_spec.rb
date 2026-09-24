require_relative "../practice_problems/problem_15_tic_tac_toe_engine"

RSpec.describe TicTacToeEngine do
  let(:engine) { described_class.new }

  let(:mid_game) do
    e = described_class.new
    e.make_move(0, 0, "X")
    e.make_move(0, 2, "O")
    e.make_move(1, 1, "X")
    e
  end

  # ---------------------------------------------------------------------------
  # PART 1 — Board Analysis
  # ---------------------------------------------------------------------------

  describe "#check_winner" do
    it "returns nil for an empty board" do
      board = [[nil, nil, nil], [nil, nil, nil], [nil, nil, nil]]
      expect(engine.check_winner(board)).to be_nil
    end

    it "detects a row win" do
      board = [%w[X X X], ["O", "O", nil], [nil, nil, nil]]
      expect(engine.check_winner(board)).to eq("X")
    end

    it "detects the last row win" do
      board = [[nil, nil, nil], ["X", "X", nil], ["O", "O", "O"]]
      expect(engine.check_winner(board)).to eq("O")
    end

    it "detects a column win" do
      board = [["O", "X", nil], ["O", "X", nil], ["O", nil, "X"]]
      expect(engine.check_winner(board)).to eq("O")
    end

    it "detects the middle column win" do
      board = [["X", "O", "X"], [nil, "O", nil], ["X", "O", nil]]
      expect(engine.check_winner(board)).to eq("O")
    end

    it "detects the main diagonal win" do
      board = [["X", "O", "O"], [nil, "X", "O"], [nil, nil, "X"]]
      expect(engine.check_winner(board)).to eq("X")
    end

    it "detects the anti-diagonal win" do
      board = [["O", "O", "X"], ["O", "X", nil], ["X", nil, nil]]
      expect(engine.check_winner(board)).to eq("X")
    end

    it "returns nil for a partial board" do
      board = [["X", "O", "X"], ["O", "X", "O"], ["O", "X", nil]]
      expect(engine.check_winner(board)).to be_nil
    end

    it "returns nil for a full board draw" do
      board = [["X", "O", "X"], ["O", "X", "O"], ["O", "X", "O"]]
      expect(engine.check_winner(board)).to be_nil
    end

    it "supports arbitrary player symbols" do
      board = [["A", "A", "A"], ["B", "B", nil], [nil, nil, nil]]
      expect(engine.check_winner(board)).to eq("A")
    end

    it "returns the correct winner among multiple symbols" do
      board = [%w[A B C], %w[C B A], %w[A B C]]
      expect(engine.check_winner(board)).to eq("B")
    end
  end

  # ---------------------------------------------------------------------------
  # PART 2 — Incremental Move Tracking
  # ---------------------------------------------------------------------------

  describe "#make_move without a winner" do
    it "returns nil mid-game" do
      expect(mid_game.make_move(2, 0, "O")).to be_nil
    end

    it "returns nil on the first move" do
      expect(engine.make_move(0, 0, "X")).to be_nil
    end
  end

  describe "#make_move with a winner" do
    it "detects a row win" do
      engine.make_move(0, 0, "X")
      engine.make_move(1, 0, "O")
      engine.make_move(0, 1, "X")
      engine.make_move(1, 1, "O")
      expect(engine.make_move(0, 2, "X")).to eq("X")
    end

    it "detects a column win" do
      engine.make_move(0, 0, "X")
      engine.make_move(0, 1, "O")
      engine.make_move(1, 0, "X")
      engine.make_move(0, 2, "O")
      expect(engine.make_move(2, 0, "X")).to eq("X")
    end

    it "detects the main diagonal win" do
      engine.make_move(0, 0, "X")
      engine.make_move(0, 1, "O")
      engine.make_move(1, 1, "X")
      engine.make_move(0, 2, "O")
      expect(engine.make_move(2, 2, "X")).to eq("X")
    end

    it "detects the anti-diagonal win" do
      engine.make_move(0, 2, "X")
      engine.make_move(0, 0, "O")
      engine.make_move(1, 1, "X")
      engine.make_move(0, 1, "O")
      expect(engine.make_move(2, 0, "X")).to eq("X")
    end

    it "detects the second player winning" do
      engine.make_move(0, 0, "X")
      engine.make_move(1, 0, "O")
      engine.make_move(0, 1, "X")
      engine.make_move(1, 1, "O")
      engine.make_move(2, 2, "X")
      expect(engine.make_move(1, 2, "O")).to eq("O")
    end
  end

  describe "#make_move errors" do
    it "raises on an occupied cell" do
      engine.make_move(0, 0, "X")
      expect { engine.make_move(0, 0, "O") }.to raise_error(ArgumentError)
    end

    it "raises when the row is out of bounds" do
      expect { engine.make_move(3, 0, "X") }.to raise_error(ArgumentError)
    end

    it "raises when the column is out of bounds" do
      expect { engine.make_move(0, 3, "X") }.to raise_error(ArgumentError)
    end

    it "raises on a negative row" do
      expect { engine.make_move(-1, 0, "X") }.to raise_error(ArgumentError)
    end

    it "raises on a negative column" do
      expect { engine.make_move(0, -1, "X") }.to raise_error(ArgumentError)
    end
  end

  describe "#get_board" do
    it "starts all nil" do
      expect(engine.get_board.flatten.all?(&:nil?)).to be true
    end

    it "reflects moves" do
      engine.make_move(0, 0, "X")
      engine.make_move(1, 1, "O")
      board = engine.get_board
      expect(board[0][0]).to eq("X")
      expect(board[1][1]).to eq("O")
      expect(board[0][1]).to be_nil
    end

    it "returns a copy, not a reference" do
      engine.make_move(0, 0, "X")
      board = engine.get_board
      board[0][0] = "TAMPERED"
      expect(engine.get_board[0][0]).to eq("X")
    end

    it "matches the board size" do
      board = engine.get_board
      expect(board.length).to eq(3)
      expect(board.all? { |row| row.length == 3 }).to be true
    end
  end

  describe "#reset" do
    it "clears the board" do
      mid_game.reset
      expect(mid_game.get_board.flatten.all?(&:nil?)).to be true
    end

    it "allows replaying after reset" do
      engine.make_move(0, 0, "X")
      engine.make_move(0, 1, "X")
      engine.reset
      expect(engine.make_move(0, 0, "X")).to be_nil
    end

    it "resets win detection" do
      engine.make_move(0, 0, "X")
      engine.make_move(1, 0, "O")
      engine.make_move(0, 1, "X")
      engine.make_move(1, 1, "O")
      engine.make_move(0, 2, "X")
      engine.reset
      engine.make_move(0, 0, "X")
      engine.make_move(1, 0, "O")
      engine.make_move(0, 1, "X")
      engine.make_move(1, 1, "O")
      expect(engine.make_move(0, 2, "X")).to eq("X")
    end
  end

  # ---------------------------------------------------------------------------
  # PART 3 — Arbitrary Board Size and Win Length
  # ---------------------------------------------------------------------------

  describe "arbitrary size" do
    it "requires a full row on a 4x4 with win_length 4" do
      e = described_class.new(size: 4, win_length: 4)
      e.make_move(0, 0, "X")
      e.make_move(0, 1, "X")
      e.make_move(0, 2, "X")
      expect(e.make_move(1, 0, "X")).to be_nil
      expect(e.make_move(0, 3, "X")).to eq("X")
    end

    it "handles a 5x5 board with win_length equal to size" do
      e = described_class.new(size: 5, win_length: 5)
      (0...4).each { |col| expect(e.make_move(0, col, "X")).to be_nil }
      expect(e.make_move(0, 4, "X")).to eq("X")
    end

    it "reflects the configured size in get_board" do
      e = described_class.new(size: 5, win_length: 3)
      board = e.get_board
      expect(board.length).to eq(5)
      expect(board.all? { |row| row.length == 5 }).to be true
    end
  end

  describe "win_length less than size" do
    it "wins a row with win_length 3 on a 5x5" do
      e = described_class.new(size: 5, win_length: 3)
      e.make_move(2, 1, "X")
      e.make_move(2, 2, "X")
      expect(e.make_move(2, 3, "X")).to eq("X")
    end

    it "wins a column with win_length 3 on a 5x5" do
      e = described_class.new(size: 5, win_length: 3)
      e.make_move(1, 4, "A")
      e.make_move(2, 4, "A")
      expect(e.make_move(3, 4, "A")).to eq("A")
    end

    it "wins a diagonal with win_length 3 on a 5x5" do
      e = described_class.new(size: 5, win_length: 3)
      e.make_move(1, 1, "B")
      e.make_move(2, 2, "B")
      expect(e.make_move(3, 3, "B")).to eq("B")
    end

    it "wins an anti-diagonal with win_length 3 on a 5x5" do
      e = described_class.new(size: 5, win_length: 3)
      e.make_move(1, 3, "O")
      e.make_move(2, 2, "O")
      expect(e.make_move(3, 1, "O")).to eq("O")
    end

    it "does not win before the run is complete" do
      e = described_class.new(size: 5, win_length: 3)
      expect(e.make_move(2, 1, "X")).to be_nil
      expect(e.make_move(2, 2, "X")).to be_nil
    end

    it "does not win with non-consecutive cells" do
      e = described_class.new(size: 5, win_length: 3)
      e.make_move(2, 0, "X")
      e.make_move(2, 2, "X")
      expect(e.make_move(2, 4, "X")).to be_nil
    end

    it "does not win when the opponent breaks the run" do
      e = described_class.new(size: 5, win_length: 3)
      e.make_move(0, 0, "X")
      e.make_move(0, 1, "O")
      expect(e.make_move(0, 2, "X")).to be_nil
    end
  end

  describe "multiple players" do
    it "handles a three-player game with a correct winner" do
      e = described_class.new(size: 4, win_length: 4)
      moves = [
        [0, 0, "A"], [0, 1, "B"], [0, 2, "C"],
        [1, 0, "A"], [1, 1, "B"], [1, 2, "C"],
        [2, 0, "A"], [2, 1, "B"], [2, 2, "C"],
        [3, 3, "A"],
      ]
      moves.each { |r, c, p| expect(e.make_move(r, c, p)).to be_nil }
      expect(e.make_move(3, 1, "B")).to eq("B")
    end

    it "does not falsely win with three players" do
      e = described_class.new(size: 3, win_length: 3)
      e.make_move(0, 0, "A")
      e.make_move(1, 0, "B")
      expect(e.make_move(2, 0, "A")).to be_nil
    end

    it "lets a fourth player win a diagonal" do
      e = described_class.new(size: 4, win_length: 3)
      e.make_move(0, 0, "A")
      e.make_move(0, 1, "B")
      e.make_move(0, 2, "C")
      e.make_move(1, 1, "D")
      e.make_move(0, 3, "A")
      e.make_move(2, 2, "D")
      expect(e.make_move(3, 3, "D")).to eq("D")
    end
  end

  describe "#check_winner with win_length" do
    it "detects a run in a row" do
      e = described_class.new(size: 5, win_length: 3)
      board = Array.new(5) { Array.new(5) }
      board[1][1] = "X"
      board[1][2] = "X"
      board[1][3] = "X"
      expect(e.check_winner(board)).to eq("X")
    end

    it "returns nil when the run is too short" do
      e = described_class.new(size: 5, win_length: 3)
      board = Array.new(5) { Array.new(5) }
      board[1][1] = "X"
      board[1][2] = "X"
      expect(e.check_winner(board)).to be_nil
    end

    it "detects a run in a column" do
      e = described_class.new(size: 5, win_length: 4)
      board = Array.new(5) { Array.new(5) }
      board[0][2] = "O"
      board[1][2] = "O"
      board[2][2] = "O"
      board[3][2] = "O"
      expect(e.check_winner(board)).to eq("O")
    end

    it "does not treat a non-consecutive row as a win" do
      e = described_class.new(size: 5, win_length: 3)
      board = Array.new(5) { Array.new(5) }
      board[2][0] = "X"
      board[2][2] = "X"
      board[2][4] = "X"
      expect(e.check_winner(board)).to be_nil
    end
  end
end
