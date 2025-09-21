import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shoefrk_admin/utils/admin_logger.dart';
import 'package:shoefrk_admin/utils/responsive_util.dart';
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
    final titleController = TextEditingController(text: artwork['title']);
    final descController = TextEditingController(text: artwork['description']);

    final allowedStatuses = ['listed', 'archived'];
    String status = allowedStatuses.contains(artwork['status'])
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
            Future<void> pickAndUploadImage({int? indexToReplace}) async {
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
                          onTap: () =>
                              pickAndUploadImage(indexToReplace: index),
                          child: Image.network(
                            imageUrls[index],
                            width: ResponsiveUtil.responsiveValue(
                              context: context,
                              mobile: 60,
                              tablet: 80,
                              desktop: 100,
                            ),
                            height: ResponsiveUtil.responsiveValue(
                              context: context,
                              mobile: 60,
                              tablet: 80,
                              desktop: 100,
                            ),
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
                        width: ResponsiveUtil.responsiveValue(
                          context: context,
                          mobile: 60,
                          tablet: 80,
                          desktop: 100,
                        ),
                        height: ResponsiveUtil.responsiveValue(
                          context: context,
                          mobile: 60,
                          tablet: 80,
                          desktop: 100,
                        ),
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
                          onPressed: () => pickAndUploadImage(),
                        ),
                      ),

                    const SizedBox(height: 12),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Title'),
                    ),
                    TextField(
                      controller: descController,
                      decoration:
                      const InputDecoration(labelText: 'Description'),
                      maxLines: 3,
                    ),
                    DropdownButtonFormField<String>(
                      value: status,
                      items: allowedStatuses
                          .map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(s),
                      ))
                          .toList(),
                      onChanged: (val) =>
                          setDialogState(() => status = val!),
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
                      'title': titleController.text.trim(),
                      'description': descController.text.trim(),
                      'status': status,
                      'image_urls': [...imageUrls, ...tempImageUrls],
                    }).eq('id', artwork['id']);

                    await AdminLogger.logAction(
                      action: "update_artwork",
                      targetId: artwork['id'].toString(),
                      targetType: "artwork",
                      details: {
                        "old_title": artwork['title'],
                        "new_title": titleController.text.trim(),
                        "old_status": artwork['status'],
                        "new_status": status,
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
            setState(() => _statusFilter = status);
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
          padding: EdgeInsets.all(
            ResponsiveUtil.responsiveValue(
              context: context,
              mobile: 8,
              tablet: 12,
              desktop: 16,
            ),
          ),
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
                        insetPadding:
                        const EdgeInsets.all(16),
                        child: SizedBox(
                          width: ResponsiveUtil
                              .responsiveValue<double>(
                            context: context,
                            mobile: MediaQuery.of(context)
                                .size
                                .width *
                                0.95,
                            tablet: 600,
                            desktop: 800,
                          ),
                          height: ResponsiveUtil
                              .responsiveValue<double>(
                            context: context,
                            mobile: MediaQuery.of(context)
                                .size
                                .height *
                                0.6,
                            tablet: 500,
                            desktop: 600,
                          ),
                          child: PageView(
                            children: (artwork['image_urls']
                            as List)
                                .map<Widget>(
                                    (url) => InteractiveViewer(
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
                    width: ResponsiveUtil.responsiveValue(
                      context: context,
                      mobile: 50,
                      tablet: 70,
                      desktop: 90,
                    ),
                    height: ResponsiveUtil.responsiveValue(
                      context: context,
                      mobile: 50,
                      tablet: 70,
                      desktop: 90,
                    ),
                    fit: BoxFit.cover,
                  ),
                )
                    : const Icon(Icons.brush),
                title: Text(
                  artwork['title'] ?? 'Untitled',
                  style: TextStyle(
                    fontSize: ResponsiveUtil.responsiveValue(
                      context: context,
                      mobile: 14,
                      tablet: 16,
                      desktop: 18,
                    ),
                  ),
                ),
                subtitle: Text(
                  artwork['created_by'] ?? 'Unknown Artist',
                  style: TextStyle(
                    fontSize: ResponsiveUtil.responsiveValue(
                      context: context,
                      mobile: 12,
                      tablet: 14,
                      desktop: 16,
                    ),
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      artwork['status'] ?? 'unknown',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: ResponsiveUtil.responsiveValue(
                          context: context,
                          mobile: 12,
                          tablet: 14,
                          desktop: 16,
                        ),
                      ),
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
