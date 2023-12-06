import "dart:io";

extension NotNullExtension<E extends Object> on E? {
  E get notNull => this!;
}

void main() {
  int? value = 3.notNull;
  stdout.writeln(value.bitLength);
}
