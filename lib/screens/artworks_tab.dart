import 'package:flutter/material.dart';
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
        .select('id, title, description, status, created_by')
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

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Artwork'),
        content: SingleChildScrollView(
          child: Column(
            children: [
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
                items: allowedStatuses.map((status) {
                  return DropdownMenuItem(
                    value: status,
                    child: Text(status[0].toUpperCase() + status.substring(1)),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) _status = value;
                },
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
            onPressed: () async {
              await supabase.from('artworks').update({
                'title': _titleController.text.trim(),
                'description': _descController.text.trim(),
                'status': _status,
              }).eq('id', artwork['id']);

              Navigator.pop(context);
              _loadArtworks();
            },
            child: const Text('Save'),
          ),
        ],
      ),
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
                leading: const Icon(Icons.brush),
                title: Text(artwork['title'] ?? 'Untitled'),
                subtitle: Text(artwork['created_by'] ?? 'Unknown Artist'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      artwork['status'] ?? 'unknown',
                      style: const TextStyle(fontWeight: FontWeight.bold),
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
