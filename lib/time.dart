import "dart:async";
import "dart:io";

void time(FutureOr<void> Function() callback, {String? name}) async {
  Stopwatch watch = Stopwatch()..start();
  switch (callback()) {
    case Future<void> future:
      await future;
      break;
    case void _:
      break;
  }

  watch.stop();

  stdout.writeln("Time${name != null ? "($name)" : ""}: ${formatMicroseconds(watch.elapsedMicroseconds)}");
}

String formatMicroseconds(int value) {
  const Map<int, String> table = <int, String>{
    1 * 1000 * 1000 * 60 * 60 * 24 * 30 * 12: "years",
    1 * 1000 * 1000 * 60 * 60 * 24 * 30: "months",
    1 * 1000 * 1000 * 60 * 60 * 24: "days",
    1 * 1000 * 1000 * 60 * 60: "hr",
    1 * 1000 * 1000 * 60: "m",
    1 * 1000 * 1000: "s",
    1 * 1000: "ms",
    1: "μs",
  };

  StringBuffer buffer = StringBuffer();
  int currentDenomination = value;

  for (var MapEntry<int, String>(key: int denomination, value: String unit) in table.entries) {
    int current = 0;
    while (denomination <= currentDenomination) {
      currentDenomination -= denomination;
      current++;
    }

    if (current == 0) {
      continue;
    }

    buffer.write("$current $unit ");
  }

  return buffer.toString().trimRight();
}
