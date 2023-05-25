// ignore_for_file: unreachable_from_main

import "dart:collection";
import "dart:io";

import "package:wave_function_collapse/shared.dart";
import "package:wave_function_collapse/stdio.dart";
import "package:wave_function_collapse/time.dart";

import "wfc.dart";

typedef Board = List2<int>;
typedef Socket = ({String top, String bottom, String left, String right});
typedef Tile = ({String display, Socket socket});
typedef SocketCheck = bool Function(int, int);
typedef Color = (int, int, int);

final class SimpleCollapse extends BacktrackingWaveFunctionCollapse {
  /// ─│┐ ┘ ┌ └
  static const List<Tile> tiles = <Tile>[
    (display: " ", socket: (top: "0", bottom: "0", left: "0", right: "0")), // 0
    (display: "─", socket: (top: "0", bottom: "0", left: "1", right: "1")), // 1
    (display: "│", socket: (top: "1", bottom: "1", left: "0", right: "0")), // 2
    (display: "┐", socket: (top: "0", bottom: "1", left: "1", right: "0")), // 3
    (display: "┘", socket: (top: "1", bottom: "0", left: "1", right: "0")), // 4
    (display: "┌", socket: (top: "0", bottom: "1", left: "0", right: "1")), // 5
    (display: "└", socket: (top: "1", bottom: "0", left: "0", right: "1")), // 6
    (display: "├", socket: (top: "1", bottom: "1", left: "0", right: "1")), // 7
    (display: "┤", socket: (top: "1", bottom: "1", left: "1", right: "0")), // 8
    (display: "┬", socket: (top: "0", bottom: "1", left: "1", right: "1")), // 9
    (display: "┴", socket: (top: "1", bottom: "0", left: "1", right: "1")), // 10
    (display: "┼", socket: (top: "1", bottom: "1", left: "1", right: "1")), // 11
    // (display: "╴", socket: (top: "0", bottom: "0", left: "1", right: "0")), // 12
    // (display: "╵", socket: (top: "1", bottom: "0", left: "0", right: "0")), // 13
    // (display: "╶", socket: (top: "0", bottom: "0", left: "0", right: "1")), // 14
    // (display: "╷", socket: (top: "0", bottom: "1", left: "0", right: "0")), // 15
  ];

  const SimpleCollapse();

  @override
  bool get displayToConsole => true;

  Wave generateWave(Board board, {required bool border}) {
    int height = board.length;
    int width = board[0].length;

    Wave wave = <List<Superposition>>[
      for (int y = 0; y < height; ++y)
        <Superposition>[
          for (int x = 0; x < width; ++x)
            <int>{
              for (int i = 0; i < tiles.length; ++i) i,
            },
        ],
    ];

    if (border) {
      /// Remove outward in the leftmost and the rightmost columns.
      for (int y = 0; y < height; ++y) {
        wave
          ..[y].first.removeWhereMapped(
              (int v) => tiles[v].socket, (Socket s) => s.left == "1" || s.bottom == "0" || s.top == "0")
          ..[y].last.removeWhereMapped(
              (int v) => tiles[v].socket, (Socket s) => s.right == "1" || s.bottom == "0" || s.top == "0");
      }

      /// Remove outward in the topmost and the bottommost columns.
      for (int x = 0; x < width; ++x) {
        wave
          ..first[x].removeWhereMapped(
              (int v) => tiles[v].socket, (Socket s) => s.top == "1" || s.left == "0" || s.right == "0")
          ..last[x].removeWhereMapped(
              (int v) => tiles[v].socket, (Socket s) => s.bottom == "1" || s.left == "0" || s.right == "0");
      }

      /// Add the corners.
      wave.first.first.add(5);
      wave.last.first.add(6);
      wave.first.last.add(3);
      wave.last.last.add(4);
    }

    return wave;
  }

  @override
  Map<Index, Set<int>> computePropagation(Wave wave, Index index, int value) {
    Map<Index, Superposition> remove = <Index, Superposition>{} //
      ..[index] = wave.get(index).difference(<int>{value});
    Queue<Index> queue = Queue<Index>()..add(index);

    while (queue.isNotEmpty) {
      var (Index index && (int y, int x)) = queue.removeFirst();
      var (int height, int width) = (wave.length, wave[y].length);

      List<(Index, SocketCheck)> neighborChecks = <(Index, SocketCheck)>[
        /// If we have a left, check left compatibility.
        if (x > 0) ((y, x - 1), (int t, int adj) => tiles[t].socket.left == tiles[adj].socket.right),

        /// If we have an up, check up compatibility.
        if (y > 0) ((y - 1, x), (int t, int adj) => tiles[t].socket.top == tiles[adj].socket.bottom),

        /// If we have a right, check right compatibility.
        if (x < width - 1) ((y, x + 1), (int t, int adj) => tiles[t].socket.right == tiles[adj].socket.left),

        /// If we have a down, check down compatibility.
        if (y < height - 1) ((y + 1, x), (int t, int adj) => tiles[t].socket.bottom == tiles[adj].socket.top),
      ];

      Superposition possibleForCurrent = wave.get(index).difference(remove[index] ?? <int>{});
      for (var (Index neighborIndex, SocketCheck check) in neighborChecks) {
        Superposition neighborPossible = wave.get(neighborIndex).difference(remove[neighborIndex] ?? <int>{});

        for (int neighborChoice in neighborPossible) {
          if (possibleForCurrent.every((int p) => !check(p, neighborChoice))) {
            remove.putIfAbsent(neighborIndex, Set.new).add(neighborChoice);

            queue.add(neighborIndex);
          }
        }
      }
    }

    return remove;
  }

  String render(Wave wave) {
    StringBuffer buffer = StringBuffer();
    for (int y = 0; y < wave.length; ++y) {
      for (int x = 0; x < wave[y].length; ++x) {
        if (x > 0) {
          Superposition left = wave[y][x - 1];
          Superposition current = wave[y][x];

          bool leftIsBar = left.length == 1 && tiles[left.single].socket.right == "1";
          bool rightIsBar = current.length == 1 && tiles[current.single].socket.left == "1";
          if (leftIsBar || rightIsBar) {
            /// If we've confirmed that one of them is a bar, then
            ///   we can put confirm that both of them will be a bar.
            // buffer.write("─");
            buffer.write("─");
          } else {
            buffer.write(" ");
          }
        }

        buffer.write(switch (wave[y][x]) {
          Superposition(length: 0) => "!",
          Superposition(length: 1, :int single) => tiles[single].display,
          Superposition(length: > 1) => "?",
          Superposition() => "",
        });
      }
      buffer.writeln();
    }

    return buffer.toString();
  }
}

const SimpleCollapse simple = SimpleCollapse();

void main() async {
  const int height = 12;
  const int width = 24;

  Board board = List2<int>.generate(height, (_) => List<int>.generate(width, (_) => -1));
  Wave wave = simple.generateWave(board, border: false);

  time(() async {
    for (var (Wave wave, _, _) in simple.collapse(wave)) {
      stdout.clear();
      stdout.writeln(simple.render(wave));
      await sleep(Duration(milliseconds: 20));
    }

    // stdout.writeln(simple.render(collapsed));
  });
}
