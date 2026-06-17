import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../widgets/shimmer_loading.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isLoading = true;
  List<dynamic> _notifications = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await ApiService.getNotifications();

    if (mounted) {
      setState(() {
        if (result['success'] == true) {
          _notifications = result['notifications'] ?? [];
        } else {
          _errorMessage = result['error'] ?? 'Failed to load notifications';
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _markAllAsRead() async {
    final result = await ApiService.markAllNotificationsRead();
    if (result['success'] == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All notifications marked as read'),
            backgroundColor: const Color(0xFF009639),
          ),
        );
        _loadNotifications();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Error updating notifications'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _onNotificationTap(Map<String, dynamic> notif) async {
    final bool isUnread = notif['is_unread'] == true || notif['is_unread'] == 1;
    if (!isUnread) return;

    final result = await ApiService.markNotificationRead(notif['id']);
    if (result['success'] == true) {
      if (mounted) {
        setState(() {
          notif['is_unread'] = false;
        });
      }
    }
  }

  String _formatDateTime(String isoString) {
    try {
      final date = DateTime.parse(isoString);
      return DateFormat('MMM dd, yyyy • hh:mm a').format(date);
    } catch (e) {
      return isoString;
    }
  }

  Map<String, dynamic> _getStyleForNotification(String title) {
    final lowerTitle = title.toLowerCase();
    if (lowerTitle.contains('approved') || lowerTitle.contains('🎉')) {
      return {'icon': Icons.check_circle, 'color': const Color(0xFF00B84A)};
    } else if (lowerTitle.contains('rejected') || lowerTitle.contains('failed') || lowerTitle.contains('alert')) {
      return {'icon': Icons.cancel, 'color': Colors.red.shade400};
    } else if (lowerTitle.contains('consideration') || lowerTitle.contains('pending')) {
      return {'icon': Icons.hourglass_top, 'color': const Color(0xFF009639)};
    } else if (lowerTitle.contains('deposit')) {
      return {'icon': Icons.account_balance_wallet, 'color': const Color(0xFF00B84A)};
    } else if (lowerTitle.contains('withdraw')) {
      return {'icon': Icons.money_off, 'color': const Color(0xFF007A2E)};
    } else if (lowerTitle.contains('transfer')) {
      return {'icon': Icons.swap_horiz, 'color': const Color(0xFF009639)};
    } else if (lowerTitle.contains('received') || lowerTitle.contains('funds')) {
      return {'icon': Icons.arrow_downward, 'color': const Color(0xFF00B84A)};
    } else if (lowerTitle.contains('shares')) {
      return {'icon': Icons.pie_chart, 'color': const Color(0xFF009639)};
    }
    return {'icon': Icons.notifications, 'color': Colors.grey};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadNotifications,
              color: const Color(0xFF007A2E),
              child: _buildContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const PageShimmer();
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 60, color: Colors.red.shade300),
              const SizedBox(height: 15),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.black87),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loadNotifications,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF007A2E)),
                child: const Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    if (_notifications.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.25),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.notifications_off_outlined, size: 80, color: Colors.grey.shade300),
                const SizedBox(height: 15),
                const Text(
                  'No notifications yet',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black54),
                ),
                const SizedBox(height: 5),
                const Text(
                  'We\'ll notify you when transaction activities happen.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _notifications.length,
      itemBuilder: (context, index) {
        final notif = _notifications[index];
        final style = _getStyleForNotification(notif['title'] ?? '');
        final bool isUnread = notif['is_unread'] == true || notif['is_unread'] == 1;

        return _buildNotificationItem(
          notif,
          notif['title'] ?? 'Notification',
          notif['message'] ?? '',
          _formatDateTime(notif['created_at'] ?? ''),
          style['icon'],
          style['color'],
          isUnread,
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    final bool hasUnread = _notifications.any((n) => n['is_unread'] == true || n['is_unread'] == 1);
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(20, topPadding + 12, 20, 30),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF009639), Color(0xFF00B84A)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(35),
          bottomRight: Radius.circular(35),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 5),
          const Expanded(
            child: Text(
              'Notifications',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
          if (hasUnread && !_isLoading && _errorMessage == null)
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text('Mark all read', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(
    Map<String, dynamic> notif,
    String title,
    String message,
    String time,
    IconData icon,
    Color color,
    bool isUnread,
  ) {
    return GestureDetector(
      onTap: () => _onNotificationTap(notif),
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: isUnread ? Border.all(color: color.withOpacity(0.3), width: 1.2) : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isUnread ? Colors.black : Colors.black87,
                          ),
                        ),
                      ),
                      if (isUnread)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    message,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isUnread ? Colors.grey.shade800 : Colors.grey.shade600, 
                      fontSize: 13, 
                      height: 1.4,
                      fontWeight: isUnread ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    time,
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
