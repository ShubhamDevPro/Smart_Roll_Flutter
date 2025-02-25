import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String userId = 'public_user';

  // Get batches for current user
  Stream<QuerySnapshot> getBatches() {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('batches')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Add new batch
  Future<DocumentReference> addBatch(
      String name, String year, IconData icon, String title) async {
    try {
      return await _firestore
          .collection('users')
          .doc(userId)
          .collection('batches')
          .add({
        'batchName': name,
        'batchYear': year,
        'icon': icon.codePoint,
        'title': title,
        'createdAt': Timestamp.now(),
      });
    } catch (e) {
      print('Error adding batch: $e');
      rethrow;
    }
  }

  // Get students in a batch
  Stream<QuerySnapshot> getStudents(String batchId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('batches')
        .doc(batchId)
        .collection('students')
        .snapshots();
  }

  // Add student to batch
  Future<void> addStudent(
      String batchId, Map<String, dynamic> studentData) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('batches')
        .doc(batchId)
        .collection('students')
        .add(studentData);
  }

  // Update student attendance
  Future<void> updateStudentAttendance(
      String batchId, String studentId, bool isPresent) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('batches')
        .doc(batchId)
        .collection('students')
        .doc(studentId)
        .update({'isPresent': isPresent});
  }

  // Delete batch and all its students
  Future<void> deleteBatch(String batchId) async {
    // Get reference to the batch
    final batchRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('batches')
        .doc(batchId);

    // Get all students in the batch
    final studentsSnapshot = await batchRef.collection('students').get();

    // Delete all students
    for (var doc in studentsSnapshot.docs) {
      await doc.reference.delete();
    }

    // Delete the batch itself
    await batchRef.delete();
  }

  // Add this new method to FirestoreService class
  Future<void> updateBatch(String batchId, String title, String batchName,
      String batchYear, int iconCodePoint) async {
    try {
      print('Updating batch with ID: $batchId');
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('batches')
          .doc(batchId)
          .update({
        'title': title,
        'batchName': batchName,
        'batchYear': batchYear,
        'icon': iconCodePoint,
      });
      print('Batch updated successfully');
    } catch (e) {
      print('Error updating batch: $e');
      rethrow;
    }
  }

  // Add new method to save attendance for a specific date
  Future<void> saveAttendanceForDate(String batchId, DateTime date,
      List<Map<String, dynamic>> attendanceData) async {
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    try {
      // Create a batch write to handle multiple operations
      WriteBatch batch = _firestore.batch();

      // First, get all students in the batch
      final studentsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('batches')
          .doc(batchId)
          .collection('students')
          .get();

      // Create a map of enrollment numbers to student documents for quick lookup
      final studentDocs = Map.fromEntries(studentsSnapshot.docs
          .map((doc) => MapEntry(doc.data()['enrollNumber'] as String, doc)));

      // For each student's attendance
      for (var studentData in attendanceData) {
        final studentDoc = studentDocs[studentData['enrollNumber']];
        if (studentDoc != null) {
          // Add attendance record to student's attendance subcollection
          final attendanceRef =
              studentDoc.reference.collection('attendance').doc(dateStr);
          batch.set(attendanceRef, {
            'date': Timestamp.fromDate(date),
            'isPresent': studentData['isPresent'],
          });
        }
      }

      // Commit the batch
      await batch.commit();
    } catch (e) {
      print('Error saving attendance: $e');
      rethrow;
    }
  }

  // Add method to get attendance for a specific date
  Stream<QuerySnapshot> getAttendanceForDate(
      String batchId, String studentId, DateTime date) {
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    return _firestore
        .collection('users')
        .doc(userId)
        .collection('batches')
        .doc(batchId)
        .collection('students')
        .doc(studentId)
        .collection('attendance')
        .where('date', isEqualTo: Timestamp.fromDate(date))
        .snapshots();
  }

  // Add this new method to get attendance for all students on a specific date
  Future<List<Map<String, dynamic>>> getAttendanceForDateAll(
      DateTime date, [String? selectedBatchId]) async {
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    List<Map<String, dynamic>> attendanceList = [];

    try {
      // If selectedBatchId is provided, get only that batch, otherwise get all batches
      final Query batchQuery = selectedBatchId != null
          ? _firestore
              .collection('users')
              .doc(userId)
              .collection('batches')
              .where(FieldPath.documentId, isEqualTo: selectedBatchId)
          : _firestore
              .collection('users')
              .doc(userId)
              .collection('batches');

      final batchesSnapshot = await batchQuery.get();

      for (var batch in batchesSnapshot.docs) {
        final studentsSnapshot =
            await batch.reference.collection('students').get();

        for (var student in studentsSnapshot.docs) {
          // Get all attendance records for this student
          final allAttendanceSnapshot =
              await student.reference.collection('attendance').get();

          // Calculate attendance statistics
          int totalDays = allAttendanceSnapshot.docs.length;
          int presentDays = allAttendanceSnapshot.docs
              .where((doc) => doc.data()['isPresent'] == true)
              .length;

          // Get attendance for the specific date
          final attendanceSnapshot = await student.reference
              .collection('attendance')
              .doc(dateStr)
              .get();

          if (attendanceSnapshot.exists) {
            attendanceList.add({
              'name': student.data()['name'],
              'enrollNumber': student.data()['enrollNumber'],
              'isPresent': attendanceSnapshot.data()?['isPresent'] ?? false,
              'batchId': batch.id,
              'totalDays': totalDays,
              'presentDays': presentDays,
            });
          }
        }
      }

      return attendanceList;
    } catch (e) {
      print('Error getting attendance: $e');
      rethrow;
    }
  }

  // Add this new method to update attendance status
  Future<void> updateAttendanceStatus(
    String batchId,
    String enrollNumber,
    DateTime date,
    bool newStatus,
  ) async {
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    try {
      // First, find the student document
      final studentsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('batches')
          .doc(batchId)
          .collection('students')
          .where('enrollNumber', isEqualTo: enrollNumber)
          .get();

      if (studentsSnapshot.docs.isEmpty) {
        throw 'Student not found';
      }

      // Update the attendance status
      final studentDoc = studentsSnapshot.docs.first;
      await studentDoc.reference
          .collection('attendance')
          .doc(dateStr)
          .update({'isPresent': newStatus});
    } catch (e) {
      print('Error updating attendance status: $e');
      rethrow;
    }
  }

  // Add this new method to get all attendance dates and data
  Future<Map<String, dynamic>> getAllAttendanceData() async {
    try {
      Set<String> allDates = {};
      Map<String, Map<String, bool>> studentAttendance = {};
      Map<String, Map<String, String>> studentInfo = {};

      // Get all batches
      final batchesSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('batches')
          .get();

      // For each batch
      for (var batch in batchesSnapshot.docs) {
        // Get all students in the batch
        final studentsSnapshot =
            await batch.reference.collection('students').get();

        // For each student
        for (var student in studentsSnapshot.docs) {
          final enrollNumber = student.data()['enrollNumber'] as String;

          // Store student info
          studentInfo[enrollNumber] = {
            'name': student.data()['name'] as String,
            'enrollNumber': enrollNumber,
          };

          // Get all attendance records for this student
          final attendanceSnapshot =
              await student.reference.collection('attendance').get();

          // Store attendance data and collect dates
          Map<String, bool> dates = {};
          for (var attendance in attendanceSnapshot.docs) {
            final date =
                attendance.id; // Using the document ID which is the date string
            dates[date] = attendance.data()['isPresent'] as bool;
            allDates.add(date);
          }
          studentAttendance[enrollNumber] = dates;
        }
      }

      return {
        'dates': allDates.toList()..sort(),
        'studentAttendance': studentAttendance,
        'studentInfo': studentInfo,
      };
    } catch (e) {
      print('Error getting all attendance data: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getAllAttendanceDataUntilDate(
    DateTime endDate,
    String? batchId,
  ) async {
    try {
      final Map<String, dynamic> studentAttendance = {};
      
      // Get all attendance records up to the selected date
      final QuerySnapshot attendanceSnapshot = await _firestore
          .collection('attendance')
          .where('batchId', isEqualTo: batchId)
          .where('date', isLessThanOrEqualTo: endDate)
          .get();

      // Process attendance records
      for (var doc in attendanceSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final date = (data['date'] as Timestamp).toDate();
        final dateStr = '${date.year}-${date.month}-${date.day}';
        
        for (var student in data['students']) {
          final enrollNo = student['enrollNumber'];
          if (!studentAttendance.containsKey(enrollNo)) {
            studentAttendance[enrollNo] = {
              'name': student['name'],
              'attendance': {}
            };
          }
          studentAttendance[enrollNo]['attendance'][dateStr] = student['isPresent'];
        }
      }

      return studentAttendance;
    } catch (e) {
      throw Exception('Failed to fetch attendance data: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getAttendanceHistory(String batchId) async {
    try {
      Map<String, Map<String, dynamic>> studentData = {};
      
      // Get all students in the batch
      final studentsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('batches')
          .doc(batchId)
          .collection('students')
          .get();

      // Process each student
      for (var student in studentsSnapshot.docs) {
        final enrollNumber = student.data()['enrollNumber'] as String;
        final name = student.data()['name'] as String;
        
        // Get all attendance records for this student
        final attendanceSnapshot = await student.reference
            .collection('attendance')
            .get();
        
        // Create attendance map
        Map<String, bool> attendance = {};
        for (var record in attendanceSnapshot.docs) {
          attendance[record.id] = record.data()['isPresent'] as bool;
        }
        
        studentData[enrollNumber] = {
          'name': name,
          'enrollNumber': enrollNumber,
          'attendance': attendance,
        };
      }
      
      return studentData.values.toList();
    } catch (e) {
      print('Error getting attendance history: $e');
      rethrow;
    }
  }
}
