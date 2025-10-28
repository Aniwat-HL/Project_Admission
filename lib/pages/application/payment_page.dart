// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:image_picker/image_picker.dart';
// import '../../services/storage_service.dart';
// import '../../services/firestore_service.dart';

// class PaymentPage extends StatefulWidget {
//   final String uid;
//   final String courseId;
//   final String courseName;
//   const PaymentPage({
//     super.key,
//     required this.uid,
//     required this.courseId,
//     required this.courseName,
//   });

//   @override
//   State<PaymentPage> createState() => _PaymentPageState();
// }

// class _PaymentPageState extends State<PaymentPage> {
//   final _picker = ImagePicker();
//   final _storage = StorageService();
//   final _fs = FirestoreService();

//   File? _selectedSlip;
//   bool uploading = false;
//   String? infoMsg;

//   Future<void> _pickSlip() async {
//     final x = await _picker.pickImage(source: ImageSource.gallery);
//     if (x != null) {
//       setState(() {
//         _selectedSlip = File(x.path);
//       });
//     }
//   }

//   Future<void> _uploadSlip() async {
//     if (_selectedSlip == null) return;
//     setState(() {
//       uploading = true;
//       infoMsg = null;
//     });
//     try {
//       final url = await _storage.uploadPaymentSlip(
//         file: _selectedSlip!,
//         uid: widget.uid,
//         courseId: widget.courseId,
//       );

//       await _fs.attachPaymentProof(
//         uid: widget.uid,
//         courseId: widget.courseId,
//         proofUrl: url,
//       );

//       setState(() {
//         infoMsg = "อัปโหลดสลิปเรียบร้อยแล้ว รอตรวจสอบ ✅";
//       });
//     } catch (e) {
//       setState(() {
//         infoMsg = "เกิดข้อผิดพลาดในการอัปโหลด: $e";
//       });
//     } finally {
//       setState(() {
//         uploading = false;
//       });
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final cName = widget.courseName;

//     return Scaffold(
//       appBar: AppBar(title: Text("ชำระเงิน: $cName")),
//       body: SafeArea(
//         minimum: const EdgeInsets.all(24),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             const Text("ขั้นตอนการชำระเงิน"),
//             const SizedBox(height: 8),
//             const Text("1. โอนเงินตามราคาคอร์ส"),
//             const Text("2. อัปโหลดสลิปด้านล่าง"),
//             const SizedBox(height: 16),

//             Expanded(
//               child: Center(
//                 child: _selectedSlip == null
//                     ? const Text("ยังไม่เลือกสลิป")
//                     : Image.file(_selectedSlip!),
//               ),
//             ),
//             const SizedBox(height: 16),

//             Row(
//               children: [
//                 Expanded(
//                   child: OutlinedButton.icon(
//                     onPressed: _pickSlip,
//                     icon: const Icon(Icons.photo),
//                     label: const Text("เลือกสลิปจากแกลเลอรี่"),
//                   ),
//                 ),
//                 const SizedBox(width: 12),
//                 Expanded(
//                   child: ElevatedButton.icon(
//                     onPressed: uploading ? null : _uploadSlip,
//                     icon: uploading
//                         ? const SizedBox(
//                             width: 16,height: 16,
//                             child: CircularProgressIndicator(strokeWidth: 2),
//                           )
//                         : const Icon(Icons.cloud_upload),
//                     label: const Text("อัปโหลดสลิป"),
//                   ),
//                 ),
//               ],
//             ),

//             if (infoMsg != null) ...[
//               const SizedBox(height: 12),
//               Text(infoMsg!),
//             ],
//           ],
//         ),
//       ),
//     );
//   }
// }
