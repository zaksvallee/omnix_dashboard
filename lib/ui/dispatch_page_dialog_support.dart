part of 'dispatch_page.dart';

extension _DispatchPageDialogSupport on _DispatchPageState {
  Future<bool?> _confirmDeleteFilterPreset(String activeName) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0A1830),
          title: Text(
            'Delete Filter Preset',
            style: GoogleFonts.inter(
              color: const Color(0xFFE5F1FF),
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'Remove "$activeName"?',
            style: GoogleFonts.inter(
              color: const Color(0xFFB9CCE6),
              fontSize: 13,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(color: const Color(0xFF8EA4C2)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                'Delete',
                style: GoogleFonts.inter(color: const Color(0xFFFFD6B2)),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _editRunNote(
    IntakeTelemetry telemetry,
    IntakeRunSummary run,
  ) async {
    final controller = TextEditingController(text: run.note);
    final updated = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0A1830),
          title: Text(
            'Edit Run Note',
            style: GoogleFonts.inter(
              color: const Color(0xFFE5F1FF),
              fontWeight: FontWeight.w700,
            ),
          ),
          content: _dialogTextField(
            controller: controller,
            hintText: 'Operator annotation',
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(color: const Color(0xFF8EA4C2)),
              ),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: Text(
                'Save',
                style: GoogleFonts.inter(color: const Color(0xFFBFD8FF)),
              ),
            ),
          ],
        );
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    if (updated == null) return;
    final nextTelemetry = telemetry.updateRunNote(
      label: run.label,
      note: updated,
    );
    widget.onTelemetryImported(nextTelemetry);
    if (!mounted) return;
    _showSnack('Run note updated');
  }

  Future<void> _editRunMetadata(
    IntakeTelemetry telemetry,
    IntakeRunSummary run,
  ) async {
    final scenarioController = TextEditingController(text: run.scenarioLabel);
    final tagsController = TextEditingController(text: run.tags.join(', '));
    final noteController = TextEditingController(text: run.note);
    final updated = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0A1830),
          title: Text(
            'Edit Run Metadata',
            style: GoogleFonts.inter(
              color: const Color(0xFFE5F1FF),
              fontWeight: FontWeight.w700,
            ),
          ),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogTextField(
                  controller: scenarioController,
                  hintText: 'Scenario label',
                  autofocus: true,
                ),
                const SizedBox(height: 10),
                _dialogTextField(
                  controller: tagsController,
                  hintText: 'Tags (comma separated)',
                ),
                const SizedBox(height: 10),
                _dialogTextField(
                  controller: noteController,
                  hintText: 'Operator annotation',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(color: const Color(0xFF8EA4C2)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop({
                'scenarioLabel': scenarioController.text.trim(),
                'tags': tagsController.text
                    .split(',')
                    .map((tag) => tag.trim())
                    .where((tag) => tag.isNotEmpty)
                    .toList(growable: false),
                'note': noteController.text.trim(),
              }),
              child: Text(
                'Save',
                style: GoogleFonts.inter(color: const Color(0xFFBFD8FF)),
              ),
            ),
          ],
        );
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      scenarioController.dispose();
      tagsController.dispose();
      noteController.dispose();
    });
    if (updated == null) return;
    final nextTelemetry = telemetry.updateRunMetadata(
      label: run.label,
      scenarioLabel: updated['scenarioLabel'] as String? ?? '',
      tags: (updated['tags'] as List?)?.cast<String>() ?? const [],
      note: updated['note'] as String? ?? '',
    );
    widget.onTelemetryImported(nextTelemetry);
    if (!mounted) return;
    _showSnack('Run metadata updated');
  }

  Future<String?> _promptForPresetName({
    required String title,
    required String actionLabel,
    required String initialValue,
  }) async {
    final controller = TextEditingController(text: initialValue);
    final value = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0A1830),
          title: Text(
            title,
            style: GoogleFonts.inter(
              color: const Color(0xFFE5F1FF),
              fontWeight: FontWeight.w700,
            ),
          ),
          content: _dialogTextField(
            controller: controller,
            hintText: 'Preset name',
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(color: const Color(0xFF8EA4C2)),
              ),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: Text(
                actionLabel,
                style: GoogleFonts.inter(color: const Color(0xFFBFD8FF)),
              ),
            ),
          ],
        );
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    return value;
  }

  Widget _dialogTextField({
    required TextEditingController controller,
    required String hintText,
    bool autofocus = false,
  }) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      style: GoogleFonts.inter(color: const Color(0xFFE5F1FF)),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.inter(color: const Color(0xFF5E7598)),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF26456F)),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF5DA3D5)),
        ),
      ),
    );
  }
}
