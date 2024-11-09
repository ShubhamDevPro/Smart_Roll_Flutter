import 'package:flutter/material.dart';
import 'package:smart_roll_call_flutter/models/batches.dart';

class CourseModal extends StatefulWidget {
  final Function(
          String title, String batchName, String batchYear, IconData iconData)
      onSave;
  final String? initialTitle;
  final String? initialBatchName;
  final String? initialBatchYear;
  final IconData? initialIcon;

  const CourseModal({
    super.key,
    required this.onSave,
    this.initialTitle,
    this.initialBatchName,
    this.initialBatchYear,
    this.initialIcon,
  });

  @override
  State<CourseModal> createState() => _CourseModalState();
}

class _CourseModalState extends State<CourseModal> {
  late final titleController = TextEditingController(text: widget.initialTitle);
  late final batchNameController =
      TextEditingController(text: widget.initialBatchName);
  late final batchYearController =
      TextEditingController(text: widget.initialBatchYear);
  late String selectedCourseType = _getCourseTypeFromIcon(widget.initialIcon);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          left: 16,
          right: 16,
          top: 16,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  widget.initialTitle == null ? 'Add New Course' : 'Edit Course',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Icon selector
            Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  child: Icon(selectedCourseType == 'Practical' ? Icons.build : Icons.book, size: 30),
                ),
                const SizedBox(width: 16),
                TextButton.icon(
                  onPressed: () => _showCourseTypePicker(context),
                  icon: const Icon(Icons.edit),
                  label: const Text('Change Course Type'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                labelText: 'Course Title',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.book),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            BatchFormFields(
              batchNameController: batchNameController,
              batchYearController: batchYearController,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _validateAndSave,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                widget.initialTitle == null ? 'Create Course' : 'Update Course',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _validateAndSave() async {
    final String title = titleController.text.trim();
    final String batchName = batchNameController.text.trim();
    final String batchYear = batchYearController.text.trim();

    if (title.isEmpty || batchName.isEmpty || batchYear.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all fields'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      final success = await widget.onSave(title, batchName, batchYear, _getIconFromCourseType(selectedCourseType));
      if (success && mounted) {
        Navigator.of(context).pop(true);  // Return true to indicate success
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding course: $e'),
          backgroundColor: Colors.red,
        ),
      );
      Navigator.of(context).pop(false);  // Return false to indicate failure
    }
  }

  void _showCourseTypePicker(BuildContext context) {
    final List<String> courseTypes = ['Theory', 'Practical'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Course Type'),
        content: Column(
          children: courseTypes.map((type) => _buildCourseTypeOption(type)).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseTypeOption(String type) {
    final isSelected = selectedCourseType == type;
    return ListTile(
      title: Text(
        type,
        style: TextStyle(
          color: isSelected ? Theme.of(context).primaryColor : null,
        ),
      ),
      onTap: () {
        setState(() => selectedCourseType = type);
        Navigator.pop(context);
      },
    );
  }

  String _getCourseTypeFromIcon(IconData? icon) {
    return icon == Icons.build ? 'Practical' : 'Theory';
  }

  IconData _getIconFromCourseType(String type) {
    return type == 'Practical' ? Icons.build : Icons.book;
  }
}
