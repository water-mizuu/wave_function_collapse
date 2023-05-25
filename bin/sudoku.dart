import "dart:collection";
import "dart:io";
import "dart:math" as math;

import "package:wave_function_collapse/shared.dart";
import "package:wave_function_collapse/stdio.dart";
import "package:wave_function_collapse/time.dart";

import "wfc.dart";

typedef Board = List2<int>;
typedef Color = (int r, int g, int b);

const SudokuCollapse sudoku = SudokuCollapse();

final class SudokuCollapse extends BacktrackingWaveFunctionCollapse {
  static const Superposition choices = <int>{1, 2, 3, 4, 5, 6, 7, 8, 9};

  @override
  bool get displayToConsole => false;

  const SudokuCollapse();

  Wave generateWave(Board board) {
    Wave wave = List2<Superposition>.generate(
      board.length,
      (int y) => List<Superposition>.generate(
        board[y].length,
        (int x) => choices.toSet(),
      ),
    );

    for (int y = 0; y < board.length; ++y) {
      for (int x = 0; x < board[y].length; ++x) {
        if (board[y][x] != 0) {
          for (var (Index index, Superposition removals) in computePropagation(wave, (y, x), board[y][x]).pairs) {
            wave.get(index).removeAll(removals);
          }
        }
      }
    }

    return wave;
  }

  @override
  Map<Index, Set<int>> computePropagation(Wave wave, Index index, int value) {
    /// We set the root to have *ALL* the other values
    ///   in it removed except the [value].

    Map<Index, Superposition> removal = <Index, Superposition>{};

    /// We set up the breadth first search for propagating collapses.
    Queue<(Index, int)> queue = Queue<(Index, int)>()..add((index, value));
    HashSet<(Index, int)> seen = HashSet<(Index, int)>();

    while (queue.isNotEmpty) {
      var (Index index && (int y, int x), int value) = queue.removeFirst();

      if (!seen.add((index, value))) {
        continue;
      }

      int size = math.sqrt(wave.length).floor();

      /// `(x ~/ c) * c` constrains `x` into multiples of `c`.
      int groupY = (y ~/ size) * size;
      int groupX = (x ~/ size) * size;

      for (int y = groupY; y < groupY + size; ++y) {
        for (int x = groupX; x < groupX + size; ++x) {
          if ((y, x) case Index check when check != index && wave.get(check).contains(value)) {
            /// If the index is not the root,
            ///   AND if the value can be removed from the wave,
            ///   then we can add this to the [removal].

            /// Reduce the values in the same group.
            removal.putIfAbsent(check, Set.new).add(value);

            if (wave.get(check).difference(removal[check]!) case Superposition(length: 1, :int single)) {
              /// If we collapsed this cell by removing some of its values,
              ///   then we add it to the queue to collapse *its* affected cells.
              queue.add((check, single));
            }
          }
        }
      }

      for (int i = 0; i < wave.length; ++i) {
        /// We check for the different [y] with same [x]
        ///   (The same column.)
        if ((i, x) case Index check when check != index && wave.get(check).contains(value)) {
          removal.putIfAbsent(check, Set.new).add(value);

          if (wave.get(check).difference(removal[check]!) case Superposition(length: 1, :int single)) {
            queue.add((check, single));
          }
        }
      }

      for (int i = 0; i < wave[0].length; ++i) {
        /// We check for the different [x] with same [y]
        ///   (The same row.)
        if ((y, i) case Index check when check != index && wave.get(check).contains(value)) {
          removal.putIfAbsent(check, Set.new).add(value);

          if (wave.get(check).difference(removal[check]!) case Superposition(length: 1, :int single)) {
            queue.add((check, single));
          }
        }
      }
    }

    return removal;
  }

  String render(Wave wave) {
    int cellSize = math.sqrt(wave.length).floor();

    StringBuffer buffer = StringBuffer();
    for (int y = 0; y < wave.length; ++y) {
      if (y > 0 && y % cellSize == 0) {
        for (int x = 0; x < wave[y].length; ++x) {
          if (x > 0 && x % cellSize == 0) {
            buffer.write("┼─");
          }
          buffer.write("──");
        }
        buffer.writeln();
      }

      for (int x = 0; x < wave[y].length; ++x) {
        if (x > 0 && x % cellSize == 0) {
          buffer.write("│ ");
        }

        buffer.write(switch (wave[y][x]) {
          Superposition(length: 0) => "!",
          Superposition(length: 1, :int single) => single.toRadixString(17).toUpperCase(),
          Superposition(length: > 1) => "?",
          Superposition() => "",
        });

        buffer.write(" ");
      }
      buffer.writeln();
    }

    return buffer.toString();
  }
}

Future<Wave> solveSudoku(Board board) async {
  Wave wave = sudoku.generateWave(board);
  Wave? solved;

  for (var (Wave wave, _, _) in sudoku.collapse(wave)) {
    solved = wave;
    stdout.clear();
    stdout.writeln(sudoku.render(wave));
    await sleep(Duration(milliseconds: 16));
  }

  return switch (solved) {
    Wave wave => wave,
    null => throw Error(),
  };
}

void main(List<String> arguments) async {
  Board board = <List<int>>[
    <int>[0, 0, 3, 0, 0, 0, 0, 0, 9],
    <int>[0, 8, 0, 2, 0, 0, 6, 3, 0],
    <int>[0, 0, 0, 0, 0, 6, 0, 0, 4],
    <int>[0, 4, 0, 0, 5, 0, 0, 0, 0],
    <int>[0, 0, 0, 0, 0, 0, 0, 9, 0],
    <int>[0, 0, 5, 0, 0, 7, 3, 2, 0],
    <int>[1, 0, 0, 8, 0, 0, 0, 0, 0],
    <int>[0, 0, 0, 0, 0, 0, 0, 0, 6],
    <int>[0, 0, 4, 0, 0, 2, 7, 5, 0],
  ];

  time(() async {
    await solveSudoku(board);
  });
}
