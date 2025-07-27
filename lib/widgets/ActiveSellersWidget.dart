import 'package:flutter/material.dart';

class ActiveSellersWidget extends StatelessWidget {
  final List<dynamic> sellers;

  const ActiveSellersWidget({
    Key? key,
    required this.sellers,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.store,
                  color: Colors.green.shade600,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Active Sellers',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (sellers.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      Icons.person_off_outlined,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No active sellers yet',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sellers.length,
                separatorBuilder: (context, index) => Divider(
                  color: Colors.grey.shade200,
                  height: 1,
                ),
                itemBuilder: (context, index) {
                  final seller = sellers[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: seller['avatar_url'] != null && seller['avatar_url'].toString().isNotEmpty
                              ? ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.network(
                              seller['avatar_url'],
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return _buildDefaultAvatar(seller);
                              },
                            ),
                          )
                              : _buildDefaultAvatar(seller),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                seller['full_name'] ?? seller['user_name'] ?? 'Unknown Seller',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              if (seller['user_name'] != null && seller['full_name'] != seller['user_name'])
                                Text(
                                  '@${seller['user_name']}',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              if (seller['email'] != null)
                                Text(
                                  seller['email'],
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Active',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar(Map<String, dynamic> seller) {
    String initials = '';
    final fullName = seller['full_name']?.toString();
    final userName = seller['user_name']?.toString();

    if (fullName != null && fullName.isNotEmpty) {
      final nameParts = fullName.split(' ');
      initials = nameParts.length >= 2
          ? '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase()
          : fullName[0].toUpperCase();
    } else if (userName != null && userName.isNotEmpty) {
      initials = userName[0].toUpperCase();
    } else {
      initials = 'S';
    }

    return Center(
      child: Text(
        initials,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.green.shade700,
          fontSize: 16,
        ),
      ),
    );
  }
}