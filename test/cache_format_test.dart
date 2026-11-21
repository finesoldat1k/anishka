import 'package:flutter_test/flutter_test.dart';

import 'package:anishka/core/cache/cache_service.dart';

void main() {
  test('formats cache sizes with russian units', () {
    expect(formatBytes(0), '0 б');
    expect(formatBytes(512), '512 б');
    expect(formatBytes(1536), '1,5 кб');
    expect(formatBytes(12 * 1024 * 1024 + 400 * 1024), '12,4 мб');
  });
}
