import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  final _storage = FirebaseStorage.instance;

  Future<String> uploadPaymentSlip({
    required File file,
    required String uid,
    required String courseId,
  }) async {
    final path = 'paymentslips/${uid}_$courseId.jpg';
    final task = await _storage.ref(path).putFile(file);
    final url = await task.ref.getDownloadURL();
    return url;
  }
}
