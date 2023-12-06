import "dart:collection";

import "package:wave_function_collapse/shared.dart";

enum CollapseMode { lowest, random }

const Duration delay = Duration(milliseconds: 20);

typedef Superposition = Set<int>;
typedef Wave = List2<Superposition>;
typedef Event = ({
  /// Index of the cell that's changed.
  Index index,

  /// The indices that were collapsed during the propagation.
  Set<Index> removals,

  /// The indices, along with the values to be removed.
  Map<Index, Set<int>> propagationMap,

  /// The tried indices during the current backtrack.
  Set<int> tried,
});

Index chooseRandomFromWave(Wave wave, Set<Index> indices) {
  Index? lowest;
  num minimum = double.infinity;
  int probability = 1;

  for (Index index in indices) {
    int length = wave.get(index).length;

    if (length < minimum) {
      lowest = index;
      minimum = length;
      probability = 1;
    } else if (length == minimum) {
      lowest = 1 / (++probability) >= random.nextDouble() ? index : lowest;
    }
  }

  return lowest ?? (throw StateError("Empty iterable"));
}

E selectRandom<E>(Iterable<E> iterable) {
  E? chosen;
  int probability = 0;
  for (E value in iterable) {
    chosen = 1 / (++probability) >= random.nextDouble() ? value : chosen;
  }

  return switch (chosen) {
    E chosen => chosen,
    null => throw StateError("Empty Iterable"),
  };
}

abstract base class BacktrackingWaveFunctionCollapse {
  const BacktrackingWaveFunctionCollapse();

  static const Set<int> _nullTried = {};
  static const Index _nullIndex = (-1, -1);

  String renderSet(Wave wave) {
    List<int> profile = [
      for (int x = 0; x < wave[0].length; ++x)
        wave //
            .map((List<Superposition> row) => row[x].toString().length)
            .reduce((int a, int b) => a > b ? a : b),
    ];

    return wave
        .map((List<Superposition> row) =>
            List<void>.generate(row.length, (int x) => row[x].toString().padRight(profile[x])).join(" "))
        .join("\n");
  }

  Set<Index> reduceIndices(Wave wave, Map<Index, Set<int>> reduction, Set<Index> indices) => //
      {
        for (var (Index key, Set<int> value) in reduction.pairs)
          if (indices.contains(key))
            if (wave.get(key).difference(value) case Superposition(length: 1)) key
      };

  Iterable<(Wave wave, Queue<Event> events, int backtrackCount)> collapse(
    Wave inputWave, [
    num count = double.infinity,
    CollapseMode mode = CollapseMode.lowest,
  ]) sync* {
    // Event queue to store the collapse events
    Queue<Event> events = Queue<Event>();

    // Create a copy of the input wave
    Wave wave = inputWave //
        .map((List<Superposition> r) => r.map((Superposition s) => s.toSet()).toList())
        .toList();

    // Counter to keep track of the number of backtracks
    int backtracks = 0;

    // Set of indices that can be collapsed
    Set<Index> indices = {
      for (int y = 0; y < wave.length; ++y)
        for (int x = 0; x < wave[y].length; ++x)
          // Add indices with multiple possibilities to the set
          if (wave[y][x].length > 1) (y, x),
    };

    Superposition tried = _nullTried;
    Index tryingIndex = _nullIndex;

    // Loop until termination conditions are met
    while (true) {
      bool backtrack = true;

      // Label for skipping the backtrack and continuing the loop
      do {
        // Termination condition: Maximum event count reached
        if (events.length >= count) {
          // If there are no empty cells, return the current wave state
          if (wave.every((List<Superposition> r) => r.every((Superposition s) => s.length == 1))) {
            yield (wave, events, backtracks);
            return;
          }
          // Force a backtrack if there are empty cells
          else {
            break;
          }
        }

        // Termination condition: No indices can be collapsed
        if (indices.isEmpty) {
          yield (wave, events, backtracks);
          return;
        }

        // Select the cell with the lowest superposition based on the collapse mode
        Index index = switch (mode) {
          _ when tryingIndex != _nullIndex => tryingIndex,
          CollapseMode.lowest => chooseRandomFromWave(wave, indices),
          CollapseMode.random => selectRandom(indices),
        };

        // Consider the untried superpositions for the selected cell
        Superposition superposition = wave.get(index);
        // assert(superposition.length != 1, "We should not have a collapsed cell selected.");

        Superposition viable = superposition.difference(tried);
        if (viable.isEmpty) {
          // If all superpositions have been tried, perform a backtrack
          break;
        }

        // Select a random value from the viable superpositions
        int value = selectRandom(viable);

        // Propagate the changes caused by the collapse and get the reduction
        Map<Index, Superposition> propagationMap = computePropagation(wave, index, value)
          ..[index] = wave.get(index).difference({value});

        // Compute the changes
        Set<Index> removals = reduceIndices(wave, propagationMap, indices);

        // Apply the reduction to update the wave
        for (var (Index index, Superposition value) in propagationMap.pairs) {
          wave.get(index).removeAll(value);
        }

        // Update the set of indices based on the reduction
        indices.removeAll(removals);

        // Record the collapse event in the event queue
        events.addLast((
          index: index,
          removals: removals,
          propagationMap: propagationMap,
          tried: tried.union({value}),
        ));

        // Reset the tried values and the trying index
        tried = _nullTried;
        tryingIndex = _nullIndex;

        backtrack = false;
        yield (wave, events, backtracks);
      } while (false);

      // This code is executed if a backtrack is necessary
      // backtrack_body:
      if (backtrack) {
        // Check if there are no events to backtrack to
        if (events.isEmpty) {
          throw Exception("This has no solution! $tried");
        }

        // Retrieve the last recorded event
        var (
          :Index index,
          :Set<Index> removals,
          :Map<Index, Superposition> propagationMap,
          tried: Superposition previousTried,
        ) = events.removeLast();

        // Increase the backtracks counter
        ++backtracks;
        // Set the trying index and tried values for backtracking
        tryingIndex = index;
        tried = previousTried;

        // Revert the changes made during the collapse
        indices.addAll(removals);

        // Undo the propagation
        for (var (Index index, Superposition value) in propagationMap.pairs) {
          wave.get(index).addAll(value);
        }

        continue;
      }
    }
  }

  Map<Index, Set<int>> computePropagation(Wave wave, Index index, int value);
}
