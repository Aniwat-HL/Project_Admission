// NOTE: อันนี้เป็นแนวทางส่งข้อมูลไป Google Form แบบ POST
// ปกติจะต้องรู้ entry.xxxxxx ของแต่ละฟิลด์ในฟอร์ม
// แล้วใช้ http.post() ไปยัง formResponse endpoint
//
// ตัวอย่างโค้ด (เปิดคอมเมนต์เมื่อคุณมี entry.xxx และ url):
//
// import 'package:http/http.dart' as http;
//
// class GoogleFormService {
//   static Future<void> sendApplication({
//     required String fullName,
//     required String phone,
//     required String courseName,
//   }) async {
//     final url = Uri.parse(
//       'https://docs.google.com/forms/d/e/<FORM_ID>/formResponse',
//     );
//
//     final resp = await http.post(url, body: {
//       'entry.11111111': fullName,
//       'entry.22222222': phone,
//       'entry.33333333': courseName,
//     });
//
//     // resp.statusCode 200/302 = ส่งแล้ว
//   }
// }
//
// ตอนนี้เราปล่อยไฟล์นี้ว่างไว้ก่อน เพราะยังไม่มี entry.* จริง
class GoogleFormService {}
