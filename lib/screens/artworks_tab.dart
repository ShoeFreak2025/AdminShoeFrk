import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shoefrk_admin/utils/admin_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ArtworksTab extends StatefulWidget {
  const ArtworksTab({super.key});

  @override
  State<ArtworksTab> createState() => _ArtworksTabState();

}

class _ArtworksTabState extends State<ArtworksTab> {
  final supabase = Supabase.instance.client;
  List<dynamic> _artworks = [];
  bool _loading = true;

  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadArtworks();
  }

  Future<void> _loadArtworks() async {
    setState(() => _loading = true);

    var query = supabase
        .from('artworks')
        .select('id, title, description, status, created_by, image_urls')
        .order('created_at', ascending: false);

    if (_statusFilter != 'all') {
      query = (query as PostgrestFilterBuilder).eq('status', _statusFilter);
    }

    final result = await query;

    setState(() {
      _artworks = result;
      _loading = false;
    });
  }

  Future<void> _editArtworkDialog(dynamic artwork) async {
    final _titleController = TextEditingController(text: artwork['title']);
    final _descController = TextEditingController(text: artwork['description']);

    final allowedStatuses = ['listed', 'archived'];
    String _status = allowedStatuses.contains(artwork['status'])
        ? artwork['status']
        : 'listed';

    List<String> imageUrls = List<String>.from(artwork['image_urls'] ?? []);
    List<String> tempImageUrls = [];

    bool isUploading = false;

    await showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> _pickAndUploadImage({int? indexToReplace}) async {
              final picker = ImagePicker();
              final pickedFile =
              await picker.pickImage(source: ImageSource.gallery);
              if (pickedFile == null) return;

              setDialogState(() => isUploading = true);
              try {
                final bytes = await pickedFile.readAsBytes();
                final fileName =
                    'artwork_${artwork['id']}_${DateTime.now().millisecondsSinceEpoch}.jpg';
                final filePath = 'artworks/$fileName';

                await supabase.storage
                    .from('documents')
                    .uploadBinary(filePath, bytes);
                final publicUrl =
                supabase.storage.from('documents').getPublicUrl(filePath);

                setDialogState(() {
                  if (indexToReplace != null) {
                    imageUrls[indexToReplace] = publicUrl;
                  } else {
                    tempImageUrls.add(publicUrl);
                  }
                });
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Upload failed: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } finally {
                setDialogState(() => isUploading = false);
              }
            }

            return AlertDialog(
              title: const Text('Edit Artwork'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Current Images (from DB):"),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(imageUrls.length, (index) {
                        return GestureDetector(
                          onTap: () => _pickAndUploadImage(indexToReplace: index),
                          child: Image.network(
                            imageUrls[index],
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 10),

                    const Text("Newly Uploaded (not saved yet):"),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: tempImageUrls
                          .map((url) => Image.network(
                        url,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      ))
                          .toList(),
                    ),
                    const SizedBox(height: 8),

                    if (isUploading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else
                      Center(
                        child: TextButton.icon(
                          icon: const Icon(Icons.add_a_photo),
                          label: const Text("Add New Photo"),
                          onPressed: () => _pickAndUploadImage(),
                        ),
                      ),

                    const SizedBox(height: 12),
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(labelText: 'Title'),
                    ),
                    TextField(
                      controller: _descController,
                      decoration: const InputDecoration(labelText: 'Description'),
                      maxLines: 3,
                    ),
                    DropdownButtonFormField<String>(
                      value: _status,
                      items: allowedStatuses
                          .map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(s),
                      ))
                          .toList(),
                      onChanged: (val) =>
                          setDialogState(() => _status = val!),
                      decoration: const InputDecoration(labelText: 'Status'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isUploading
                      ? null
                      : () async {
                    await supabase.from('artworks').update({
                      'title': _titleController.text.trim(),
                      'description': _descController.text.trim(),
                      'status': _status,
                      'image_urls': [...imageUrls, ...tempImageUrls],
                    }).eq('id', artwork['id']);

                    await AdminLogger.logAction(
                      action: "update_artwork",
                      targetId: artwork['id'].toString(),
                      targetType: "artwork",
                      details: {
                        "old_title": artwork['title'],
                        "new_title": _titleController.text.trim(),
                        "old_status": artwork['status'],
                        "new_status": _status,
                      },
                    );

                    Navigator.pop(context);
                    _loadArtworks();
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildFilterChips() {
    const filters = ['all', 'listed', 'archived'];

    return Wrap(
      spacing: 8,
      children: filters.map((status) {
        final isSelected = _statusFilter == status;
        return ChoiceChip(
          label: Text(status[0].toUpperCase() + status.substring(1)),
          selected: isSelected,
          onSelected: (_) {
            setState(() {
              _statusFilter = status;
            });
            _loadArtworks();
          },
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: _buildFilterChips(),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _artworks.isEmpty
              ? const Center(child: Text('No artworks found.'))
              : ListView.builder(
            itemCount: _artworks.length,
            itemBuilder: (context, index) {
              final artwork = _artworks[index];
              return ListTile(
                leading: (artwork['image_urls'] != null &&
                    artwork['image_urls'].isNotEmpty)
                    ? GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => Dialog(
                        insetPadding: const EdgeInsets.all(16),
                        child: SizedBox(
                          width: MediaQuery.of(context).size.width * 0.8,
                          height: MediaQuery.of(context).size.height * 0.5,
                          child: PageView(
                            children: (artwork['image_urls'] as List)
                                .map<Widget>((url) => InteractiveViewer(
                              child: Image.network(
                                url,
                                fit: BoxFit.contain,
                              ),
                            ))
                                .toList(),
                          ),
                        ),
                      ),
                    );
                  },
                  child: Image.network(
                    artwork['image_urls'][0],
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                  ),
                )
                    : const Icon(Icons.brush),
                title: Text(artwork['title'] ?? 'Untitled'),
                subtitle:
                Text(artwork['created_by'] ?? 'Unknown Artist'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      artwork['status'] ?? 'unknown',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _editArtworkDialog(artwork),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
