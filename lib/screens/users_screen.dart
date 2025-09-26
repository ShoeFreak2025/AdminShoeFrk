import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shoefrk_admin/utils/admin_logger.dart';
import 'package:shoefrk_admin/utils/responsive_util.dart';
import 'package:shoefrk_admin/widgets/sidebar_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

class UsersScreen extends StatefulWidget {
  final Function(String)? onNavigate;

  const UsersScreen({Key? key, this.onNavigate}) : super(key: key);

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

  void _handleNavigation(String route) {
    if (widget.onNavigate != null) {
      widget.onNavigate!(route);
    } else {
      String routeName;
      switch (route) {
        case 'dashboard':
          routeName = '/dashboard';
          break;
        case 'users':
          routeName = '/users';
          break;
        case 'seller_verification':
          routeName = '/seller-verification';
          break;
        case 'products':
          routeName = '/products';
          break;
        case 'release_payouts':
          routeName = '/release-payouts';
          break;
        default:
          routeName = '/dashboard';
      }

      Navigator.of(context).pushReplacementNamed(routeName);
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
                          : comments
                          .map((comment) => ListTile(
                        title: Text(comment['comment'] ?? ''),
                        subtitle: Text('By: ${comment['user_name'] ?? 'Anonymous'}'),
                      ))
                          .toList(),
                    ),
                  );
                },
              ),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
          ),
        ),
      );
    } catch (e) {
      Navigator.pop(context);
      _showErrorSnackBar('Failed to open user posts: $e');
    }
  }

  Widget _buildUserTile(Map<String, dynamic> user) {
    final isDeleted = user['is_deleted'] ?? false;
    return ListTile(
      leading: CircleAvatar(child: Text(user['full_name']?[0]?.toUpperCase() ?? '?')),
      title: Text(
        user['full_name'] ?? 'Unnamed',
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        user['email'] ?? 'No email',
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.article, color: Colors.blue),
            onPressed: () => _openUserPosts(user['id'], user['full_name'] ?? 'User'),
          ),
          IconButton(
            icon: const Icon(Icons.admin_panel_settings, color: Colors.purple),
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
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final isDeleted = user['is_deleted'] ?? false;
    final roles = user['role'] as List? ?? [];

    return Card(
      elevation: 2,
      child: IntrinsicHeight(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    child: Text(
                      user['full_name']?[0]?.toUpperCase() ?? '?',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      user['full_name'] ?? 'Unnamed',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                user['email'] ?? 'No email',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
              if (roles.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: roles
                      .take(3)
                      .map((role) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getRoleColor(role.toString()),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      role.toString(),
                      style: const TextStyle(
                        fontSize: 9,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ))
                      .toList(),
                ),
              ],
              const Spacer(),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        iconSize: 16,
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        icon: const Icon(Icons.article, color: Colors.blue),
                        onPressed: () => _openUserPosts(user['id'], user['full_name'] ?? 'User'),
                        tooltip: 'Posts',
                      ),
                      IconButton(
                        iconSize: 16,
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        icon: const Icon(Icons.admin_panel_settings, color: Colors.purple),
                        onPressed: () => _editUserRoles(user),
                        tooltip: 'Roles',
                      ),
                    ],
                  ),
                  Transform.scale(
                    scale: 0.7,
                    child: Switch(
                      value: isDeleted,
                      onChanged: (_) => _toggleUserDeleted(user['id'], isDeleted),
                      activeColor: Colors.red,
                      inactiveThumbColor: Colors.green,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Colors.red;
      case 'seller':
        return Colors.green;
      case 'artist':
        return Colors.purple;
      case 'buyer':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_users.isEmpty) {
      return const Center(child: Text("No users found."));
    }

    return ResponsiveUtil.responsiveValue(
      context: context,
      mobile: ListView.separated(
        itemCount: _users.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) => _buildUserTile(_users[index]),
      ),
      tablet: _buildResponsiveGrid(crossAxisCount: 3),
      desktop: _buildResponsiveGrid(crossAxisCount: 5),
    );
  }

  Widget _buildResponsiveGrid({required int crossAxisCount}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          for (int i = 0; i < _users.length; i += crossAxisCount)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (int j = 0; j < crossAxisCount; j++)
                      if (i + j < _users.length) ...[
                        Expanded(child: _buildUserCard(_users[i + j])),
                        if (j < crossAxisCount - 1) const SizedBox(width: 16),
                      ] else
                        const Expanded(child: SizedBox()),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onNavigate != null) {
      return _buildBody();
    }

    return Scaffold(
      appBar: ResponsiveUtil.isMobile(context)
          ? AppBar(
        title: const Text('Manage Users'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      )
          : null,
      drawer: ResponsiveUtil.isMobile(context)
          ? SidebarWidget(
        onNavigate: _handleNavigation,
        currentRoute: 'users',
      )
          : null,
      body: Row(
        children: [
          if (ResponsiveUtil.isDesktop(context))
            SidebarWidget(
              onNavigate: _handleNavigation,
              currentRoute: 'users',
            ),
          Expanded(
            child: Column(
              children: [
                if (ResponsiveUtil.isDesktop(context))
                  Container(
                    height: 60,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: const Row(
                      children: [
                        Text(
                          'Manage Users',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}