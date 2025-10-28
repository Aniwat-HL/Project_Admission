import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';
import '../../models/course.dart';

enum EditCourseMode { create, edit }

class EditCoursePage extends StatefulWidget {
  final EditCourseMode mode;
  final Course? existingCourse;

  const EditCoursePage({
    super.key,
    required this.mode,
    this.existingCourse,
  });

  @override
  State<EditCoursePage> createState() => _EditCoursePageState();
}

class _EditCoursePageState extends State<EditCoursePage> {
  final _nameCtl = TextEditingController();
  final _descCtl = TextEditingController();
  final _priceCtl = TextEditingController();

  bool _isOpen = true;
  bool saving = false;
  String? saveMsg;

  // วัน/เวลา
  DateTime? _startDate;
  DateTime? _endDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  @override
  void initState() {
    super.initState();

    if (widget.mode == EditCourseMode.edit && widget.existingCourse != null) {
      final c = widget.existingCourse!;

      _nameCtl.text = c.title;
      _descCtl.text = c.description;
      _priceCtl.text = c.price.toString();
      _isOpen = c.isOpen;

      _startDate = c.startDate;
      _endDate = c.endDate;

      if (c.startTime != null && c.startTime!.contains(':')) {
        final parts = c.startTime!.split(':');
        final hh = int.tryParse(parts[0]) ?? 9;
        final mm = int.tryParse(parts[1]) ?? 0;
        _startTime = TimeOfDay(hour: hh, minute: mm);
      }
      if (c.endTime != null && c.endTime!.contains(':')) {
        final parts = c.endTime!.split(':');
        final hh = int.tryParse(parts[0]) ?? 12;
        final mm = int.tryParse(parts[1]) ?? 0;
        _endTime = TimeOfDay(hour: hh, minute: mm);
      }
    } else {
      _isOpen = true;
    }
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _descCtl.dispose();
    _priceCtl.dispose();
    super.dispose();
  }

  // ---------- helpers for UI ----------

  String _dateLabel(DateTime? d) {
    if (d == null) return "ยังไม่เลือก";
    return "${d.day}/${d.month}/${d.year}";
  }

  String _timeLabel(TimeOfDay? t) {
    if (t == null) return "ยังไม่เลือก";
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return "$hh:$mm";
  }

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: DateTime(now.year + 2),
      initialDate: _startDate ?? now,
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        if (_endDate == null) {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _pickEndDate() async {
    if (_startDate == null) {
      await _pickStartDate();
      if (_startDate == null) return;
    }

    final picked = await showDatePicker(
      context: context,
      firstDate: _startDate!,
      lastDate: DateTime(_startDate!.year + 2),
      initialDate: _endDate ?? _startDate!,
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) {
      setState(() {
        _startTime = picked;
        if (_endTime == null) {
          final guessHour = (picked.hour + 1).clamp(0, 23);
          _endTime = TimeOfDay(hour: guessHour, minute: picked.minute);
        }
      });
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime ?? const TimeOfDay(hour: 12, minute: 0),
    );
    if (picked != null) {
      setState(() {
        _endTime = picked;
      });
    }
  }

  String _buildScheduleString() {
    if (_startDate == null ||
        _endDate == null ||
        _startTime == null ||
        _endTime == null) {
      return "ยังไม่ได้เลือกวัน/เวลา";
    }

    final startDateText =
        "${_startDate!.day}/${_startDate!.month}/${_startDate!.year}";
    final endDateText =
        "${_endDate!.day}/${_endDate!.month}/${_endDate!.year}";

    final stH = _startTime!.hour.toString().padLeft(2, '0');
    final stM = _startTime!.minute.toString().padLeft(2, '0');
    final enH = _endTime!.hour.toString().padLeft(2, '0');
    final enM = _endTime!.minute.toString().padLeft(2, '0');

    if (startDateText == endDateText) {
      return "วันที่ $startDateText เวลา $stH:$stM - $enH:$enM";
    } else {
      return "วันที่ $startDateText - $endDateText เวลา $stH:$stM - $enH:$enM";
    }
  }

  Future<void> _handleSave() async {
    final title = _nameCtl.text.trim();
    final desc = _descCtl.text.trim();
    final priceText = _priceCtl.text.trim();
    final price = double.tryParse(priceText) ?? 0.0;

    if (title.isEmpty) {
      setState(() {
        saveMsg = "กรุณากรอกชื่อคอร์ส";
      });
      return;
    }

    if (_startDate == null ||
        _endDate == null ||
        _startTime == null ||
        _endTime == null) {
      setState(() {
        saveMsg = "กรุณาเลือกวันและเวลาเรียนให้ครบ";
      });
      return;
    }

    final scheduleString = _buildScheduleString();

    setState(() {
      saving = true;
      saveMsg = null;
    });

    final fs = FirestoreService();

    try {
      if (widget.mode == EditCourseMode.create) {
        await fs.createCourse(
          title: title,
          description: desc,
          schedule: scheduleString,
          price: price,
          isOpen: _isOpen,
          startDate: _startDate!,
          endDate: _endDate!,
          startTime: _startTime!,
          endTime: _endTime!,
        );
      } else {
        await fs.updateCourse(
          courseId: widget.existingCourse!.id,
          title: title,
          description: desc,
          schedule: scheduleString,
          price: price,
          isOpen: _isOpen,
          startDate: _startDate!,
          endDate: _endDate!,
          startTime: _startTime!,
          endTime: _endTime!,
        );
      }

      if (!mounted) return;
      Navigator.pop(context, true); // true = ให้หน้าเดิม refresh
    } catch (e) {
      if (!mounted) return;
      setState(() {
        saveMsg = "บันทึกไม่สำเร็จ: $e";
      });
    } finally {
      if (!mounted) return;
      setState(() {
        saving = false;
      });
    }
  }

  Future<void> _confirmDelete() async {
    // ปุ่มนี้จะถูกเรียกเฉพาะโหมดแก้ไข (มี existingCourse)
    final courseId = widget.existingCourse?.id;
    if (courseId == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("ลบคอร์สนี้?"),
          content: const Text(
            "คุณต้องการลบคอร์สนี้จริงหรือไม่?\nการลบจะเอาเอกสารคอร์สออกจาก Firestore ทันที",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("ยกเลิก"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("ลบเลย"),
            ),
          ],
        );
      },
    );

    if (ok != true) return;

    final fs = FirestoreService();
    setState(() {
      saving = true;
      saveMsg = null;
    });

    try {
      await fs.deleteCourse(courseId);

      if (!mounted) return;
      // ปิดหน้านี้ พร้อมส่ง true กลับ
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        saving = false;
        saveMsg = "ลบไม่สำเร็จ: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.mode == EditCourseMode.edit;
    final schedulePreview = _buildScheduleString();

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? "แก้ไขคอร์ส" : "เพิ่มคอร์สใหม่"),
        actions: [
          if (isEdit)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              tooltip: "ลบคอร์สนี้",
              onPressed: saving ? null : _confirmDelete,
            ),
        ],
      ),
      body: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: ListView(
          children: [
            // ชื่อคอร์ส
            TextField(
              controller: _nameCtl,
              decoration: const InputDecoration(
                labelText: "ชื่อคอร์ส",
                hintText: "เช่น English for Job",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // รายละเอียดคอร์ส
            TextField(
              controller: _descCtl,
              decoration: const InputDecoration(
                labelText: "รายละเอียดคอร์ส",
                hintText: "สิ่งที่จะได้เรียน, รูปแบบการสอน...",
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 16),

            // วันที่เริ่ม / วันที่จบ
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _pickStartDate,
                    child: Column(
                      children: [
                        const Text("วันที่เริ่ม"),
                        Text(_dateLabel(_startDate)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _pickEndDate,
                    child: Column(
                      children: [
                        const Text("วันที่จบ"),
                        Text(_dateLabel(_endDate)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // เวลาเริ่ม / เวลาจบ
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _pickStartTime,
                    child: Column(
                      children: [
                        const Text("เวลาเริ่ม"),
                        Text(_timeLabel(_startTime)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _pickEndTime,
                    child: Column(
                      children: [
                        const Text("เวลาจบ"),
                        Text(_timeLabel(_endTime)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // preview schedule
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blueGrey.shade100),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.event_available, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      schedulePreview,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ราคา
            TextField(
              controller: _priceCtl,
              decoration: const InputDecoration(
                labelText: "ราคา (บาท)",
                hintText: "เช่น 1999",
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),

            // เปิด/ปิดรับสมัคร
            Row(
              children: [
                Switch(
                  value: _isOpen,
                  onChanged: (val) {
                    setState(() {
                      _isOpen = val;
                    });
                  },
                  activeColor: Colors.green,
                ),
                const SizedBox(width: 8),
                Text(
                  _isOpen ? "เปิดรับสมัคร" : "ปิดรับสมัคร",
                  style: TextStyle(
                    color: _isOpen ? Colors.green : Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),

            if (saveMsg != null) ...[
              const SizedBox(height: 12),
              Text(
                saveMsg!,
                style: const TextStyle(color: Colors.red),
              ),
            ],

            const SizedBox(height: 24),

            // ปุ่มบันทึก
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(saving ? "กำลังบันทึก..." : "บันทึก"),
                onPressed: saving ? null : _handleSave,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            if (isEdit) ...[
              const SizedBox(height: 16),
              // ปุ่มลบคอร์ส (สำรองอีกจุด ถ้าไม่ได้กดจาก AppBar)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  label: const Text(
                    "ลบคอร์สนี้",
                    style: TextStyle(color: Colors.red),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: saving ? null : _confirmDelete,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
