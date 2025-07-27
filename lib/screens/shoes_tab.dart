import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ShoesTab extends StatefulWidget {
  const ShoesTab({super.key});

  @override
  State<ShoesTab> createState() => _ShoesTabState();
}

class _ShoesTabState extends State<ShoesTab> {
  final supabase = Supabase.instance.client;
  List<dynamic> _shoes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadShoes();
  }

  Future<void> _loadShoes() async {
    setState(() => _loading = true);
    final result = await supabase
        .from('shoes')
        .select('id, shoe_name, brand, price, status, color, seller_id, image_urls')        .order('created_at', ascending: false);
    setState(() {
      _shoes = result;
      _loading = false;
    });
  }

  final Map<String, Color> namedColors = {
    'red': Colors.red,
    'blue': Colors.blue,
    'green': Colors.green,
    'yellow': Colors.yellow,
    'orange': Colors.orange,
    'purple': Colors.purple,
    'pink': Colors.pink,
    'brown': Colors.brown,
    'black': Colors.black,
    'white': Colors.white,
    'grey': Colors.grey,
  };

  String getClosestColorName(Color color) {
    String closestName = 'custom';
    double minDistance = double.infinity;

    namedColors.forEach((name, c) {
      final distance = ((c.red - color.red) * (c.red - color.red) +
          (c.green - color.green) * (c.green - color.green) +
          (c.blue - color.blue) * (c.blue - color.blue)).toDouble();
      if (distance < minDistance) {
        minDistance = distance;
        closestName = name;
      }
    });

    return closestName;
  }


  Future<void> _editShoeDialog(dynamic shoe) async {
    final _nameController = TextEditingController(text: shoe['shoe_name']);
    final _brandController = TextEditingController(text: shoe['brand']);
    final _priceController = TextEditingController(text: shoe['price'].toString());

    final allowedStatuses = ['listed', 'archived'];
    String _status = allowedStatuses.contains(shoe['status']) ? shoe['status'] : 'listed';
    List<String> _selectedColors = (shoe['color'] as List?)?.cast<String>() ?? [];

    bool _isUploading = false;
    List<String> imageUrls = List<String>.from(shoe['image_urls'] as List? ?? []);

    Future<void> _pickAndUploadImage(StateSetter setDialogState, {int? indexToReplace}) async {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null) return;

      setDialogState(() => _isUploading = true);
      try {
        final bytes = await pickedFile.readAsBytes();
        final fileName = 'shoe_${shoe['id']}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final filePath = 'valiID/$fileName';

        await supabase.storage.from('documents').uploadBinary(filePath, bytes);
        final publicUrl = supabase.storage.from('documents').getPublicUrl(filePath);

        setDialogState(() {
          if (indexToReplace != null) {
            imageUrls[indexToReplace] = publicUrl;
          } else {
            imageUrls.add(publicUrl);
          }
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
          );
        }
      } finally {
        setDialogState(() => _isUploading = false);
      }
    }

    void _addColor(BuildContext context, StateSetter setDialogState) {
      Color pickerColor = Colors.blue;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Pick a color'),
          content: SingleChildScrollView(child: ColorPicker(pickerColor: pickerColor, onColorChanged: (c) => pickerColor = c)),
          actions: [
            TextButton(
              child: const Text('Add'),
              onPressed: () {
                final colorName = getClosestColorName(pickerColor);
                if (!_selectedColors.contains(colorName)) {
                  setDialogState(() => _selectedColors.add(colorName));
                }
                Navigator.pop(context);
              },
            ),
          ],
        ),
      );
    }

    await showDialog(
      context: context,
      barrierDismissible: !_isUploading,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Shoe'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Photos (tap to replace):"),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(imageUrls.length, (index) {
                    return GestureDetector(
                      onTap: () => _pickAndUploadImage(setState, indexToReplace: index),
                      child: Image.network(imageUrls[index], width: 80, height: 80, fit: BoxFit.cover),
                    );
                  }),
                ),

                const SizedBox(height: 8),

                if (_isUploading)
                  const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()))
                else
                  Center(
                    child: TextButton.icon(
                      icon: const Icon(Icons.add_a_photo),
                      label: const Text("Add New Photo"),
                      onPressed: () => _pickAndUploadImage(setState),
                    ),
                  ),

                const SizedBox(height: 10),
                TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Shoe Name')),
                TextField(controller: _brandController, decoration: const InputDecoration(labelText: 'Brand')),
                TextField(controller: _priceController, decoration: const InputDecoration(labelText: 'Price'), keyboardType: TextInputType.number),
                DropdownButtonFormField<String>(
                  value: _status,
                  items: allowedStatuses.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (val) => setState(() => _status = val!),
                  decoration: const InputDecoration(labelText: 'Status'),
                ),

                const SizedBox(height: 12),
                const Text('Colors:', style: TextStyle(fontWeight: FontWeight.bold)),
                Wrap(
                  spacing: 8,
                  children: List.generate(_selectedColors.length, (index) {
                    final name = _selectedColors[index];
                    final color = namedColors[name] ?? Colors.grey;
                    return Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.black26)),
                    );
                  }),
                ),
                Center(child: TextButton.icon(icon: const Icon(Icons.color_lens), label: const Text("Add Color"), onPressed: () => _addColor(context, setState))),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: _isUploading ? null : () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: _isUploading
                  ? null
                  : () async {
                await supabase.from('shoes').update({
                  'shoe_name': _nameController.text.trim(),
                  'brand': _brandController.text.trim(),
                  'price': double.tryParse(_priceController.text.trim()) ?? 0,
                  'status': _status,
                  'color': _selectedColors,
                  'image_urls': imageUrls,
                }).eq('id', shoe['id']);
                Navigator.pop(context);
                _loadShoes();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleStatus(dynamic shoe) async {
    final newStatus = (shoe['status'] == 'listed') ? 'archived' : 'listed';
    await supabase
        .from('shoes')
        .update({'status': newStatus})
        .eq('id', shoe['id']);

    _loadShoes();
  }

  Future<void> _reportShoeDialog(dynamic shoe) async {
    final TextEditingController _reasonController = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Report Shoe'),
        content: TextField(
          controller: _reasonController,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'Enter reason for reporting'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final reason = _reasonController.text.trim();
              final user = supabase.auth.currentUser;

              if (reason.isNotEmpty && user != null) {
                await supabase.from('notifications').insert({
                  'user_id': user.id,
                  'seller_id': shoe['seller_id'],
                  'shoes_id': shoe['id'],
                  'title': 'Shoe Report',
                  'content': reason,
                  'is_read': false,
                });

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Shoe reported successfully')),
                );
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
      itemCount: _shoes.length,
      itemBuilder: (context, index) {
        final shoe = _shoes[index];
        return ListTile(
          leading: const Icon(Icons.shopping_bag),
          title: Text(shoe['shoe_name'] ?? 'Unnamed'),
          subtitle: Text('${shoe['brand']} - ₱${shoe['price']}'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                shoe['status'] ?? 'unknown',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: shoe['status'] == 'listed' ? Colors.green : Colors.grey,
                ),
              ),
              IconButton(
                icon: Icon(
                  shoe['status'] == 'listed' ? Icons.archive : Icons.unarchive,
                  color: Colors.orange,
                ),
                tooltip: shoe['status'] == 'listed' ? 'Archive' : 'Restore',
                onPressed: () => _toggleStatus(shoe),
              ),
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.blue),
                onPressed: () => _editShoeDialog(shoe),
              ),
              IconButton(
                icon: const Icon(Icons.report, color: Colors.red),
                onPressed: () => _reportShoeDialog(shoe),
              ),
            ],
          ),
        );
      },
    );
  }
}
