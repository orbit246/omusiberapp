import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:omusiber/backend/notes_service.dart';
import 'package:omusiber/backend/view/note_model.dart';
import 'package:omusiber/pages/new_view/note_editor_page.dart';

class NotesTabView extends StatefulWidget {
  const NotesTabView({super.key});

  @override
  State<NotesTabView> createState() => _NotesTabViewState();
}

class _NotesTabViewState extends State<NotesTabView> {
  List<Note> _notes = [];
  bool _isLoading = true;
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    final notes = await NotesService().getNotes();
    if (mounted) {
      setState(() {
        _notes = notes;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteNote(String id) async {
    await NotesService().deleteNote(id);
    _loadNotes();
  }

  List<Note> get _filteredNotes {
    if (_searchQuery.isEmpty) return _notes;
    return _notes.where((n) {
      return n.content.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          n.category.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  Future<void> _openEditor({Note? note}) async {
    final result = await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => NoteEditorPage(note: note)));

    if (result == true) {
      _loadNotes();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final notesToList = _filteredNotes;

    // Manual Masonry: Split into two columns
    List<Note> col1 = [];
    List<Note> col2 = [];
    for (int i = 0; i < notesToList.length; i++) {
      if (i % 2 == 0)
        col1.add(notesToList[i]);
      else
        col2.add(notesToList[i]);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,

      // We will put the gradient in the body container if MasterView doesn't provide it.
      // Assuming MasterView has standard background. We want a special one.
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          "Not Ekle",
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.black,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor, // Use flat background
        child: Column(
          children: [
            // Header & Search
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search Bar
                  TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: "Notlarda ara...",
                      hintStyle: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      filled: true,
                      fillColor: Theme.of(context).cardColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 0,
                        horizontal: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Note Grid
            Expanded(
              child: notesToList.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.notes,
                            size: 64,
                            color: Colors.grey.withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Henüz not yok.",
                            style: GoogleFonts.inter(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      itemCount: notesToList.length,
                      itemBuilder: (context, index) {
                        return _buildNoteCard(notesToList[index]);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteCard(Note note) {
    // If color is 0, use theme card color. Else use the stored color.
    Color cardColor = note.color == 0
        ? Theme.of(context).cardColor
        : Color(note.color);

    // Text Color Logic:
    // If Theme Default (0), adapt to theme (White/Black).
    // If Custom Color (Mockup Pastels), always use Black for readability on bright pastels.
    // Unless in future we add dark custom colors, but for now assuming pastels.
    final Color textColor = note.color == 0
        ? (Theme.of(context).brightness == Brightness.dark
              ? Colors.white
              : Colors.black87)
        : Colors.black87;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => _openEditor(note: note),
        onLongPress: () {
          // Confirm delete
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text("Not silinsin mi?"),
              content: const Text("Bu işlem geri alınamaz."),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("İptal"),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _deleteNote(note.id);
                  },
                  child: const Text("Sil", style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          );
        },
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20), // Match mockup roundness
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title / Category
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        note.category,
                        style: GoogleFonts.inter(
                          fontSize: 18, // Slightly larger
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      Icons.edit_outlined,
                      size: 18,
                      color: textColor.withOpacity(0.5),
                    ),
                  ],
                ),
              ),
              // Content
              Text(
                note.content,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                  color: textColor.withOpacity(0.9),
                ),
                maxLines: 8,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
