import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shoefrk_admin/utils/admin_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({Key? key}) : super(key: key);

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final supabase = Supabase.instance.client;
  List<dynamic> _users = [];
  bool _isLoading = true;
  Uint8List? previewImageBytes;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final data = await supabase
          .from('users')
          .select('id, full_name, email, role, is_deleted')
          .order('created_at', ascending: false);
      if (mounted) setState(() => _users = data);
    } catch (e) {
      _showErrorSnackBar('Failed to fetch users: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleUserDeleted(String userId, bool currentValue) async {
    try {
      await supabase.from('users').update({'is_deleted': !currentValue}).eq('id', userId);
      _loadUsers();

      await AdminLogger.logAction(
        action: "toggle_user_status",
        targetId: userId,
        targetType: "user",
        details: {"new_status": !currentValue},
      );
    } catch (e) {
      _showErrorSnackBar('Failed to update user: $e');
    }
  }

  Future<void> _editUserRoles(Map<String, dynamic> user) async {
    List<String> currentRoles = List<String>.from(user['role'] ?? []);
    const allRoles = ['buyer', 'seller', 'artist', 'admin'];

    final updatedRoles = await showDialog<List<String>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit Roles for ${user['full_name'] ?? 'User'}'),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: allRoles.map((role) {
                    return CheckboxListTile(
                      title: Text(role),
                      value: currentRoles.contains(role),
                      onChanged: (selected) {
                        setDialogState(() {
                          if (selected == true) {
                            currentRoles.add(role);
                          } else {
                            currentRoles.remove(role);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              );
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(context, currentRoles), child: const Text('Save')),
          ],
        );
      },
    );

    if (updatedRoles != null) {
      try {
        await supabase.from('users').update({
          'role': updatedRoles,
          'is_admin': updatedRoles.contains('admin'),
        }).eq('id', user['id']);
        _loadUsers();

        await AdminLogger.logAction(
          action: "edit_user_roles",
          targetId: user['id'].toString(),
          targetType: "user",
          details: {"roles": updatedRoles},
        );
      } catch (e) {
        _showErrorSnackBar('Failed to update roles: $e');
      }
    }
  }

  Future<void> _reportPost(Map<String, dynamic> post) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Post?'),
        content: const Text('Are you sure you want to report this post?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Report')),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await supabase.from('notifications').insert({
          'user_id': user.id,
          'seller_id': post['author_id'],
          'social_post_id': post['id'],
          'title': 'Post Report',
          'content': 'Post reported',
          'is_read': false,
        });

        await AdminLogger.logAction(
          action: "report_post",
          targetId: post['id'].toString(),
          targetType: "post",
          details: {"reported_by": user.id},
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post reported successfully')));
        }
      } catch (e) {
        _showErrorSnackBar('Failed to report post: $e');
      }
    }
  }

  Future<void> _editPost(Map<String, dynamic> post, VoidCallback onPostUpdated) async {
    final controller = TextEditingController(text: post['content']);
    final List<String> mediaUrls = List<String>.from(post['media_urls'] ?? []);
    String? currentImageUrl = mediaUrls.isNotEmpty ? mediaUrls.first : null;
    XFile? pickedImage;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Post'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: controller, maxLines: 5, decoration: const InputDecoration(labelText: 'Content')),
                const SizedBox(height: 16),
                if (pickedImage != null && previewImageBytes != null)
                  Image.memory(previewImageBytes!, height: 120, fit: BoxFit.cover)
                else if (currentImageUrl != null)
                  Image.network(currentImageUrl, height: 120, fit: BoxFit.cover)
                else
                  const Text('No image attached'),
                const SizedBox(height: 8),
                TextButton.icon(
                  icon: const Icon(Icons.photo),
                  label: const Text('Change Photo'),
                  onPressed: () async {
                    final picker = ImagePicker();
                    final file = await picker.pickImage(source: ImageSource.gallery);
                    if (file != null) {
                      final bytes = await file.readAsBytes();
                      setDialogState(() {
                        pickedImage = file;
                        previewImageBytes = bytes;
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                try {
                  String? newImageUrl;
                  if (pickedImage != null) {
                    final bytes = await pickedImage!.readAsBytes();
                    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
                    const bucket = 'documents';
                    final path = 'valiID/$fileName';

                    await supabase.storage.from(bucket).uploadBinary(path, bytes);
                    newImageUrl = supabase.storage.from(bucket).getPublicUrl(path);
                  }

                  await supabase.from('social_posts').update({
                    'content': controller.text.trim(),
                    'media_urls': [if (newImageUrl != null) newImageUrl else if (currentImageUrl != null) currentImageUrl],
                    'updated_at': DateTime.now().toIso8601String()
                  }).eq('id', post['id']);

                  await AdminLogger.logAction(
                    action: "edit_post",
                    targetId: post['id'].toString(),
                    targetType: "post",
                    details: {
                      "new_content": controller.text.trim(),
                      "updated_media": newImageUrl ?? currentImageUrl
                    },
                  );

                  Navigator.pop(context);
                  onPostUpdated();
                } catch (e) {
                  _showErrorSnackBar('Failed to save post: $e');
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openUserPosts(String userId, String userName) async {
    showDialog(context: context, builder: (_) => const Center(child: CircularProgressIndicator()), barrierDismissible: false);

    try {
      final List<dynamic> posts = await supabase
          .from('social_posts')
          .select('*, social_post_comments(*)')
          .eq('author_id', userId)
          .order('created_at', ascending: false);

      Navigator.pop(context);
      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (_) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text('Posts by $userName'),
            content: SizedBox(
              width: double.maxFinite,
              child: posts.isEmpty
                  ? const Text('No posts found.')
                  : ListView.builder(
                shrinkWrap: true,
                itemCount: posts.length,
                itemBuilder: (context, index) {
                  final post = posts[index];
                  final comments = post['social_post_comments'] as List<dynamic>;

                  return Card(
                    child: ExpansionTile(
                      title: Text(post['content'] ?? '[No Content]', maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: Text('Comments: ${comments.length}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                              icon: const Icon(Icons.report, color: Colors.red),
                              onPressed: () => _reportPost(post)),
                          IconButton(
                              icon: const Icon(Icons.edit, color: Colors.orange),
                              onPressed: () => _editPost(post, () {
                                Navigator.pop(context);
                                _openUserPosts(userId, userName);
                              })),
                          Switch(
                              value: post['is_deleted'] ?? false,
                              onChanged: (newValue) async {
                                try {
                                  await supabase.from('social_posts').update({'is_deleted': newValue}).eq('id', post['id']);
                                  setDialogState(() => post['is_deleted'] = newValue);
                                  await AdminLogger.logAction(
                                    action: "toggle_post_status",
                                    targetId: post['id'].toString(),
                                    targetType: "post",
                                    details: {"new_status": newValue},
                                  );

                                } catch (e) {
                                  _showErrorSnackBar('Failed to update post status: $e');
                                }
                              }),
                        ],
                      ),
                      children: comments.isEmpty
                          ? [const ListTile(title: Text('No comments found.'))]
                          : comments.map((comment) => ListTile(
                        title: Text(comment['comment'] ?? ''),
                        subtitle: Text('By: ${comment['user_name'] ?? 'Anonymous'}'),
                      )).toList(),
                    ),
                  );
                },
              ),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
          ),
        ),
      );
    } catch(e) {
      Navigator.pop(context);
      _showErrorSnackBar('Failed to open user posts: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Users')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
          ? const Center(child: Text("No users found."))
          : ListView.separated(
        itemCount: _users.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final user = _users[index];
          final isDeleted = user['is_deleted'] ?? false;
          return ListTile(
            leading: CircleAvatar(child: Text(user['full_name']?[0]?.toUpperCase() ?? '?')),
            title: Text(user['full_name'] ?? 'Unnamed'),
            subtitle: Text(user['email'] ?? 'No email'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.article, color: Colors.blue),
                  tooltip: 'Manage Posts',
                  onPressed: () => _openUserPosts(user['id'], user['full_name'] ?? 'User'),
                ),
                IconButton(
                  icon: const Icon(Icons.admin_panel_settings, color: Colors.purple),
                  tooltip: 'Manage Roles',
                  onPressed: () => _editUserRoles(user),
                ),
                Switch(
                  value: isDeleted,
                  onChanged: (_) => _toggleUserDeleted(user['id'], isDeleted),
                  activeColor: Colors.red,
                  inactiveThumbColor: Colors.green,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}