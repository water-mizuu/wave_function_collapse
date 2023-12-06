// ignore_for_file: always_specify_types

import "dart:async";
import "dart:collection";
import "dart:isolate";
import "dart:math" as math;

import "package:wave_function_collapse/shared.dart";

import "wfc.dart";

typedef Board = List2<int>;

const SudokuCollapse sudoku = SudokuCollapse();

final class SudokuCollapse extends BacktrackingWaveFunctionCollapse {
  static const Superposition choices = {1, 2, 3, 4, 5, 6, 7, 8, 9};

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

    Map<Index, Superposition> removal = {};

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

typedef IsolateReturn = (int iterations, Wave wave);

Future<Wave> solveSudoku(Board board) async {
  Wave wave = sudoku.generateWave(board);

  bool hasFinished = false;
  List<(SendPort, Completer<IsolateReturn?>)> isolates = [];

  for (int i = 0; i < 100; ++i) {
    /// This is the [ReceivePort] that will be used to communicate with the isolate.

    ReceivePort outerReceivePort = ReceivePort();
    await Isolate.spawn(((SendPort, Wave, int) payload) async {
      var (SendPort outerSendPort, Wave wave, int index) = payload;

      ReceivePort cancellationPort = ReceivePort();

      /// Now we start the actual multiprocessing.
      cancellationPort.listen((dynamic message) {
        assert(message is bool, "This must only be a [bool].");

        if (message as bool) {
          outerSendPort.send(null);
          cancellationPort.close();
          Isolate.current.kill(priority: Isolate.immediate);
        }
      });
      outerSendPort.send(cancellationPort.sendPort);

      IsolateReturn? solved;
      for (var (int tries, (Wave wave, _, _)) in sudoku.collapse(wave).indexed) {
        solved = (tries, wave);
        await Future<void>.delayed(Duration(milliseconds: 16));
      }

      if (solved case (int iterations, _) && IsolateReturn solved) {
        print("Isolate #$index has finished with $iterations iterations.");
        outerSendPort.send(solved);

        /// How do we kill this?
      } else {
        outerSendPort.send(null);
      }
    }, (outerReceivePort.sendPort, wave, i));

    int listenIndex = 0;

    Completer<SendPort> sendPortCompleter = Completer<SendPort>();
    Completer<IsolateReturn?> resultCompleter = Completer<IsolateReturn?>();

    void listener(dynamic message) {
      switch (listenIndex) {
        case 0:
          assert(message is SendPort, "The first message must be a [SendPort].");
          sendPortCompleter.complete(message as SendPort);
        case 1:
          assert(message is IsolateReturn?, "The first message must be a [Wave].");

          if (!hasFinished && message != null) {
            for (var (SendPort innerSendPort, _) in isolates) {
              innerSendPort.send(true);
            }
          }

          resultCompleter.complete(message as IsolateReturn?);
          outerReceivePort.close();
          hasFinished = true;

        default:
          throw Exception("The listen index of $listenIndex with type ${message.runtimeType} is not handled.");
      }
      listenIndex++;
    }

    outerReceivePort.listen(listener);

    /// Start the isolate.
    SendPort sendPort = await sendPortCompleter.future;

    isolates.add((sendPort, resultCompleter));
  }

  List<(int, Wave)?> solved = await Future.wait([
    for (var (_, completer) in isolates) completer.future,
  ]);

  print(solved);

  Wave solution = solved.whereType<(int, Wave)>().first.$2;

  return solution;
}

void main(List<String> arguments) async {
  Board board = [
    [0, 0, 3, 0, 0, 0, 0, 0, 9],
    [0, 8, 0, 2, 0, 0, 6, 3, 0],
    [0, 0, 0, 0, 0, 6, 0, 0, 4],
    [0, 4, 0, 0, 5, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 9, 0],
    [0, 0, 5, 0, 0, 7, 3, 2, 0],
    [1, 0, 0, 8, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0, 6],
    [0, 0, 4, 0, 0, 2, 7, 5, 0],
  ];

  Wave solved = await solveSudoku(board);
  print("Solved with:\n${sudoku.render(solved)}");
}
