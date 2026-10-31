import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Answers requests from a callback, so tests need no network.
/// Throw a [DioException] from the callback to simulate a network failure.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.yanitla);

  final ResponseBody Function(RequestOptions istek) yanitla;
  final List<RequestOptions> istekler = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    istekler.add(options);
    return yanitla(options);
  }

  @override
  void close({bool force = false}) {}

  String yol(int i) => istekler[i].path;
}

ResponseBody jsonYanit(int kod, Object? govde) => ResponseBody.fromString(
      jsonEncode(govde),
      kod,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
