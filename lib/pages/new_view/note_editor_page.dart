import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:omusiber/backend/notes_service.dart';
import 'package:omusiber/backend/view/note_model.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
// import 'package:url_launcher/url_launcher.dart'; // Optional for links

class NoteEditorPage extends StatefulWidget {
  final Note? note; // If null, create new

  const NoteEditorPage({super.key, this.note});

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  late TextEditingController _titleController;
  late MarkdownSyntaxController _contentController; // Custom controller
  late int _selectedColor;
  bool _isPreviewMode = false;
  // Duplicate _isDirty removed here

  final List<int> _colors = [
    0, // Theme Default (Auto)
    0xFFFD99FF, // Vibrant Pink
    0xFFFF9E9E, // Red
    0xFF91F48F, // Green
    0xFFFFF599, // Yellow
    0xFF9EFFFF, // Cyan
    0xFFB69CFF, // Purple
    0xFFFFFFFF, // White
  ];

  @override
  void initState() {
    super.initState();
    // Default to 0 (Theme Auto) if new note, or if existing note has no color (unlikely but safe)
    _selectedColor = widget.note?.color ?? 0;
    _titleController = TextEditingController(text: widget.note?.category ?? "");
    _contentController = MarkdownSyntaxController(
      // Use custom controller
      text: widget.note?.content ?? "",
    );

    // Default to preview mode if opening an existing note with content
    if (widget.note != null && widget.note!.content.isNotEmpty) {
      _isPreviewMode = true;
    }

    if (widget.note == null) {
      _suggestContext();
    }
  }

  Future<void> _suggestContext() async {
    try {
      final suggestion = await NotesService().suggestContext();
      if (mounted && _titleController.text.isEmpty) {
        _titleController.text = suggestion;
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image != null) {
        final appDir = await getApplicationDocumentsDirectory();
        if (!mounted) return;

        final fileName = p.basename(image.path);
        final localImage = await File(
          image.path,
        ).copy('${appDir.path}/$fileName');

        if (!mounted) return;
        _insertMarkdown("![Image](${localImage.uri})");
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Resim eklenemedi: $e")));
    }
  }

  void _saveNote() {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (content.isEmpty && title.isEmpty) {
      // Empty note, maybe just discard or warn?
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Boş not kaydedilemez.")));
      return;
    }

    final now = DateTime.now();
    final note = Note(
      id: widget.note?.id ?? NotesService().createId(),
      category: title.isEmpty ? "Genel" : title,
      content: content,
      createdAt: widget.note?.createdAt ?? now,
      updatedAt: now,
      color: _selectedColor,
    );

    NotesService().saveNote(note);
    Navigator.pop(context, true); // Return true to indicate saved
  }

  void _insertMarkdown(String syntax) {
    final text = _contentController.text;
    final selection = _contentController.selection;

    // Default cursor at end if no selection
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;

    String newText;
    int newSelectionIndex;

    // Simple toggle logic or wrap
    if (syntax == "**" || syntax == "_" || syntax == "`" || syntax == "__") {
      // Wrap selection
      final selectedText = text.substring(start, end);
      newText = text.replaceRange(start, end, "$syntax$selectedText$syntax");
      newSelectionIndex =
          start + syntax.length + selectedText.length + syntax.length;
      if (selectedText.isEmpty) {
        // Cursor inside
        newSelectionIndex = start + syntax.length;
      }
    } else if (syntax.startsWith("# ") ||
        syntax.startsWith("- ") ||
        syntax.startsWith("> ") ||
        syntax.startsWith("![Image]")) {
      // Image insertion
      // Line start check? Simplify: just insert at cursor
      newText = text.replaceRange(start, end, "$syntax");
      newSelectionIndex = start + syntax.length;
    } else {
      newText = text.replaceRange(start, end, syntax);
      newSelectionIndex = start + syntax.length;
    }

    _contentController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newSelectionIndex),
    );
    _isDirty = true;
  }

  bool _isDirty = false;

  @override
  Widget build(BuildContext context) {
    // Determine status bar / text readability based on background
    final Color bgColor = _selectedColor == 0
        ? Theme.of(context).scaffoldBackgroundColor
        : Color(_selectedColor);

    final bool isDarkBg =
        ThemeData.estimateBrightnessForColor(bgColor) == Brightness.dark;

    // Use pure white/black logic for the crisp look in mockup if background is dark/light
    final Color textColor = _selectedColor == 0
        ? (isDarkBg ? const Color(0xFFEEEEEE) : Colors.black87)
        : (isDarkBg ? Colors.white : Colors.black87);

    final Color iconColor = _selectedColor == 0
        ? (isDarkBg ? Colors.white70 : Colors.black54)
        : (isDarkBg ? Colors.white70 : Colors.black54);

    // Button styling helper
    Widget circularButton({
      required IconData icon,
      required VoidCallback onTap,
    }) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: isDarkBg
              ? Colors.white.withOpacity(0.1)
              : Colors.black.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12), // Squircle-ish
        ),
        child: IconButton(
          icon: Icon(icon, color: textColor, size: 20),
          onPressed: onTap,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          padding: EdgeInsets.zero,
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        if (!_isDirty && widget.note != null) {
          Navigator.pop(context);
          return;
        }
        // Show dialog
        final shouldSave = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF2C2C2C),
            title: const Icon(Icons.info, color: Colors.grey, size: 32),
            content: const Text(
              "Save changes?",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx, false),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                ),
                child: const Text("Discard"),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                ),
                child: const Text("Save"),
              ),
            ],
          ),
        );

        if (shouldSave != null) {
          if (shouldSave)
            _saveNote();
          else if (context.mounted)
            Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leadingWidth: 60,
          titleSpacing: 0,
          leading: Center(
            child: circularButton(
              icon: Icons.arrow_back,
              onTap: () => Navigator.maybePop(context),
            ),
          ),
          actions: [
            circularButton(
              icon: Icons.palette_outlined,
              onTap: () => _showColorPicker(),
            ),
            circularButton(
              icon: _isPreviewMode
                  ? Icons.edit_outlined
                  : Icons.remove_red_eye_outlined,
              onTap: () => setState(() => _isPreviewMode = !_isPreviewMode),
            ),
            circularButton(icon: Icons.save_outlined, onTap: _saveNote),
            const SizedBox(width: 12),
          ],
        ),
        body: Column(
          children: [
            // Title Field
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: TextField(
                controller: _titleController,
                onChanged: (_) => _isDirty = true,
                style: GoogleFonts.inter(
                  fontSize: 34,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                  height: 1.2,
                ),
                cursorColor: textColor,
                decoration: InputDecoration(
                  hintText: "Title",
                  hintStyle: GoogleFonts.inter(
                    fontSize: 34,
                    fontWeight: FontWeight.w600,
                    color: isDarkBg ? Colors.white24 : Colors.black26,
                  ),
                  filled: false,
                  fillColor: Colors.transparent,
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),

            Expanded(
              child: _isPreviewMode
                  ? Markdown(
                      data: _contentController.text,
                      styleSheet: MarkdownStyleSheet(
                        p: GoogleFonts.inter(
                          fontSize: 16,
                          height: 1.6,
                          color: textColor,
                        ),
                        h1: GoogleFonts.inter(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                        h2: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                        h3: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                        blockquote: TextStyle(
                          color: iconColor,
                          fontStyle: FontStyle.italic,
                        ),
                        code: GoogleFonts.firaCode(
                          backgroundColor: isDarkBg
                              ? Colors.white10
                              : Colors.black.withOpacity(0.05),
                          color: textColor,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      imageBuilder: (uri, title, alt) {
                        if (uri.scheme == 'file') {
                          return Image.file(File(uri.toFilePath()));
                        }
                        // Fallback to default network image handling (or asset)
                        // But Markdown widget doesn't expose default builder easily.
                        // We can just return Image.network for http/https
                        if (uri.scheme == 'http' || uri.scheme == 'https') {
                          return Image.network(uri.toString());
                        }
                        return Container(); // Placeholder or error
                      },
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: TextField(
                        controller: _contentController,
                        onChanged: (_) => _isDirty = true,
                        maxLines: null,
                        expands: true,
                        style: GoogleFonts.inter(
                          fontSize: 17,
                          height: 1.6,
                          color: textColor.withOpacity(0.9),
                        ),
                        cursorColor: textColor,
                        decoration: InputDecoration(
                          hintText: "Type something...",
                          hintStyle: GoogleFonts.inter(
                            fontSize: 17,
                            color: isDarkBg ? Colors.white24 : Colors.black26,
                          ),
                          filled: false,
                          fillColor: Colors.transparent,
                          border: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                        ),
                      ),
                    ),
            ),

            // Toolbar (Only in Edit Mode)
            if (!_isPreviewMode)
              Container(
                decoration: BoxDecoration(
                  color: bgColor,
                  border: Border(
                    top: BorderSide(
                      color: isDarkBg ? Colors.white10 : Colors.black12,
                    ),
                  ),
                ),
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _FormatButton(
                        icon: Icons.format_bold,
                        onTap: () => _insertMarkdown("**"),
                        color: iconColor,
                      ),
                      _FormatButton(
                        icon: Icons.format_italic,
                        onTap: () => _insertMarkdown("_"),
                        color: iconColor,
                      ),
                      _FormatButton(
                        icon: Icons.format_underline,
                        onTap: () => _insertMarkdown("__"),
                        color: iconColor,
                      ), // Mockup has underline
                      const SizedBox(width: 8),
                      _FormatButton(
                        icon: Icons.title,
                        onTap: () => _insertMarkdown("# "),
                        color: iconColor,
                      ),
                      _FormatButton(
                        icon: Icons.format_list_bulleted,
                        onTap: () => _insertMarkdown("- "),
                        color: iconColor,
                      ),
                      _FormatButton(
                        icon: Icons.check_box_outlined,
                        onTap: () => _insertMarkdown("- [ ] "),
                        color: iconColor,
                      ),
                      _FormatButton(
                        icon: Icons.image_outlined,
                        onTap: _pickImage,
                        color: iconColor,
                      ),
                      const SizedBox(width: 8),
                      _FormatButton(
                        icon: Icons.code,
                        onTap: () => _insertMarkdown("`"),
                        color: iconColor,
                      ),
                      _FormatButton(
                        icon: Icons.format_quote,
                        onTap: () => _insertMarkdown("> "),
                        color: iconColor,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showColorPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Choose Background",
              style: GoogleFonts.inter(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: _colors.map((c) {
                final isSelected = _selectedColor == c;
                final colorToShow = c == 0
                    ? Theme.of(context).colorScheme.surface
                    : Color(c);
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedColor = c);
                    _isDirty = true;
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: colorToShow,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.withOpacity(0.3)),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: Theme.of(context).primaryColor,
                                blurRadius: 0,
                                spreadRadius: 2,
                              ),
                            ]
                          : [],
                    ),
                    child: c == 0
                        ? Icon(
                            Icons.auto_awesome,
                            color: Theme.of(context).iconTheme.color,
                          )
                        : null,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormatButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _FormatButton({
    required this.icon,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: color),
      visualDensity: VisualDensity.compact,
    );
  }
}

class MarkdownSyntaxController extends TextEditingController {
  MarkdownSyntaxController({super.text});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final List<TextSpan> children = [];
    final pattern = RegExp(
      r"(\*\*.+?\*\*)|(__.+?__)|(\*.+?\*)|(_.+?_)|(^#+ .*)|(!\[.*?\]\(.*?\))|(`.+?`)",
      multiLine: true,
    );

    style ??= const TextStyle();
    final Color textColor = style.color ?? Colors.black;
    final bool isDark = textColor.computeLuminance() > 0.5;
    // Faint color for syntax markers
    final Color syntaxColor = isDark ? Colors.white24 : Colors.black26;

    text.splitMapJoin(
      pattern,
      onMatch: (Match match) {
        final String matchText = match[0]!;
        TextStyle matchStyle = style ?? const TextStyle();

        if (match.group(1) != null || match.group(2) != null) {
          // Bold
          children.add(
            TextSpan(
              text: matchText.substring(0, 2),
              style: matchStyle.copyWith(color: syntaxColor),
            ),
          );
          children.add(
            TextSpan(
              text: matchText.substring(2, matchText.length - 2),
              style: matchStyle.copyWith(fontWeight: FontWeight.bold),
            ),
          );
          children.add(
            TextSpan(
              text: matchText.substring(matchText.length - 2),
              style: matchStyle.copyWith(color: syntaxColor),
            ),
          );
        } else if (match.group(3) != null || match.group(4) != null) {
          // Italic
          children.add(
            TextSpan(
              text: matchText.substring(0, 1),
              style: matchStyle.copyWith(color: syntaxColor),
            ),
          );
          children.add(
            TextSpan(
              text: matchText.substring(1, matchText.length - 1),
              style: matchStyle.copyWith(fontStyle: FontStyle.italic),
            ),
          );
          children.add(
            TextSpan(
              text: matchText.substring(matchText.length - 1),
              style: matchStyle.copyWith(color: syntaxColor),
            ),
          );
        } else if (match.group(5) != null) {
          // Header
          // Count #
          int hashCount = matchText.indexOf(" ");
          if (hashCount < 1) hashCount = 1; // Fallback
          // Apply larger font size based on level
          double size = 24.0 - (hashCount * 2);
          if (size < 16) size = 16;

          children.add(
            TextSpan(
              text: matchText.substring(0, hashCount),
              style: matchStyle.copyWith(color: syntaxColor),
            ),
          );
          children.add(
            TextSpan(
              text: matchText.substring(hashCount),
              style: matchStyle.copyWith(
                fontSize: size,
                fontWeight: FontWeight.bold,
                color: textColor, // Ensure visibility
              ),
            ),
          );
        } else if (match.group(7) != null) {
          // Code
          children.add(
            TextSpan(
              text: matchText,
              style: GoogleFonts.firaCode(
                backgroundColor: isDark ? Colors.white10 : Colors.grey.shade200,
                color: textColor,
              ),
            ),
          );
        } else {
          // Other matches
          children.add(TextSpan(text: matchText, style: matchStyle));
        }
        return "";
      },
      onNonMatch: (String text) {
        children.add(TextSpan(text: text, style: style));
        return "";
      },
    );

    return TextSpan(style: style, children: children);
  }
}
