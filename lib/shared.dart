import "dart:math" as math;

typedef List2<E> = List<List<E>>;
typedef Index = (int y, int x);

final math.Random random = math.Random();

extension SetExtension<E> on Set<E> {
  void removeWhereMapped<O>(O Function(E) mapper, bool Function(O) test) {
    removeWhere((E e) => test(mapper(e)));
  }
}

extension List2Methods<E> on List2<E> {
  E get(Index index) {
    List<E> row = this[index.$1 % length];

    return row[index.$2 % row.length];
  }

  E set(Index index, E value) {
    List<E> row = this[index.$1 % length];

    return row[index.$2 % row.length] = value;
  }
}

extension MapMethods<K, V> on Map<K, V> {
  Iterable<(K, V)> get pairs sync* {
    for (var MapEntry<K, V>(:K key, :V value) in entries) {
      yield (key, value);
    }
  }
}
