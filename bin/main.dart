import "dart:io";

extension NotNullExtension<E extends Object> on E? {
  E get notNull => switch (this) {
        E e => e,
        null => throw Error(),
      };
}

void main() {
  int? value = 3.notNull;
  stdout.writeln(value.bitLength);
}
