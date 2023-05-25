import "dart:collection";
import "dart:io";
import "dart:math";

typedef Rgb = (int r, int g, int b);

extension RgbMethods on Rgb {
  int get r => $1;
  int get g => $2;
  int get b => $3;

  String get ansi => "$r;$g;$b";
}

extension StdoutExt on Stdout {
  static String _clearCode = String.fromCharCodes(<int>[27, 99, 27, 91, 51, 74]);
  static String _bellCode = String.fromCharCode(0x07);
  static String _escapeCode = "\x1B[";
  static String _hideCursorCode = "?25l";
  static String _showCursorCode = "?25h";
  static String _clearLineCode = "2K";
  static String _moveUpCode = "A";
  static String _moveDownCode = "B";
  static String _moveRightCode = "C";
  static String _moveLeftCode = "D";
  static String _moveToColumnCode = "G";
  static String _resetForegroundCode = "39m";
  static String _resetBackgroundCode = "49m";
  static bool _cursorHidden = false;

  void print([Object object = ""]) => write(object);
  void println([Object object = ""]) => writeln(object);
  void printAll(List<Object> objects, {String separator = ""}) => <void>[
        for (Object obj in objects) <void>[stdout.writeln(obj), if (obj != objects.last) stdout.writeln(separator)]
      ];

  void newln([int n = 1]) => stdout.writeln("\n" * n);

  String escape(String s) => "$_escapeCode$s";
  void _esc(String s) => write("$_escapeCode$s");
  void bell() => write(_bellCode);

  void resetForegroundColor() => _esc(_resetForegroundCode);
  void resetBackgroundColor() => _esc(_resetBackgroundCode);
  void setForegroundColor(Rgb color) => _esc("38;2;${color.ansi}m");
  void setBackgroundColor(Rgb color) => _esc("48;2;${color.ansi}m");
  void resetColor() => <void>[resetBackgroundColor(), resetForegroundColor()];

  void clear() => write(_clearCode);
  void clearScreen() => write(_clearCode);
  void clearln() => <void>[_esc(_clearLineCode), movelnStart()];
  void clearlnsUp([int n = 1]) => <void>[
        clearln(),
        for (int i = 1; i < n; i++) <void>[moveUp(), clearln()]
      ];
  void clearlnsDown([int n = 1]) => <void>[
        clearln(),
        for (int i = 1; i < n; i++) <void>[moveUp(), clearln()]
      ];

  void moveUp([int n = 1]) => <void>[if (n != 0) _esc("$n$_moveUpCode")];
  void moveDown([int n = 1]) => <void>[if (n != 0) _esc("$n$_moveDownCode")];
  void moveRight([int n = 1]) => <void>[if (n != 0) _esc("$n$_moveRightCode")];
  void moveLeft([int n = 1]) => <void>[if (n != 0) _esc("$n$_moveLeftCode")];
  void movelnStart() => _esc("1$_moveToColumnCode");
  void movelnEnd() => _esc("1000000000$_moveToColumnCode");

  void up([int n = 1]) => moveUp(n);
  void down([int n = 1]) => moveDown(n);
  void right([int n = 1]) => moveRight(n);
  void left([int n = 1]) => moveLeft(n);
  void start() => movelnStart();
  void end() => movelnEnd();

  void hideCursor() => _esc(_hideCursorCode);
  void showCursor() => _esc(_showCursorCode);
  void sessionHideCursor() => hideCursor();
  void toggleCursor() => !(_cursorHidden = !_cursorHidden) ? showCursor() : hideCursor();

  // Overloads
  void set foregroundColor(Rgb color) => setForegroundColor(color);
  void set backgroundColor(Rgb color) => setBackgroundColor(color);
}

Future<void> sleep(Duration duration) => Future<void>.delayed(duration);

class Screen {
  final Queue<((int, int), String)> changes;
  final List<List<String>> values;
  final int width;
  final int height;

  Screen({
    required this.width,
    required this.height,
  })  : values = <List<String>>[
          for (int y = 0; y < height; ++y) <String>[for (int x = 0; x < width; ++x) "."]
        ],
        changes = Queue<((int, int), String)>();

  void initialize() {
    stdout.clear();
    stdout.writeAll(values.map<String>((List<String> r) => r.join()), "\n");
    stdout.writeln();
  }

  void update(String newScreen) {
    List<String> grid = newScreen.split("\n");

    for (int y = 0, yMin = min(height, grid.length); y < yMin; ++y) {
      for (int x = 0, xMin = min(width, grid[y].length); x < xMin; ++x) {
        if (grid[y][x] != values[y][x]) {
          changes.add(((y, x), grid[y][x]));
        }
      }
    }

    stdout
      ..hideCursor()
      ..start();

    /// This method assumes that the cursor is at the last.
    while (changes.isNotEmpty) {
      var ((int y, int x), String c) = changes.removeFirst();
      int vertical = height - y;

      // Position.
      stdout
        ..up(vertical)
        ..right(x)
        ..write(c)

        // Reverse.
        ..down(vertical)
        ..start();
    }

    stdout.showCursor();
  }
}
