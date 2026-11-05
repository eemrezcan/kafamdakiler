import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Keeps a copy of each picked photo in the app's own folder. The picker's file
/// lives in a cache the system may clear, and an offline capture can wait days
/// for its upload.
class FotografDeposu {
  /// [klasor] is replaced in tests; the app uses its documents folder.
  FotografDeposu({Future<Directory> Function()? klasor}) : _klasor = klasor ?? _varsayilanKlasor;

  static const _uuid = Uuid();

  final Future<Directory> Function() _klasor;

  static Future<Directory> _varsayilanKlasor() async {
    final belgeler = await getApplicationDocumentsDirectory();
    return Directory('${belgeler.path}${Platform.pathSeparator}yakalamalar');
  }

  /// Copies [kaynakYol] into the folder under a new name and returns the copy's path.
  Future<String> kopyala(String kaynakYol) async {
    final klasor = await _klasor();
    await klasor.create(recursive: true);
    final nokta = kaynakYol.lastIndexOf('.');
    final uzanti = nokta > kaynakYol.lastIndexOf(Platform.pathSeparator) ? kaynakYol.substring(nokta) : '.jpg';
    final hedef = '${klasor.path}${Platform.pathSeparator}${_uuid.v7()}$uzanti';
    await File(kaynakYol).copy(hedef);
    return hedef;
  }
}
