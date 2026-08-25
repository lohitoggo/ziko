import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/supabase_auth_provider.dart';
import '../providers/area_provider.dart';
import '../providers/user_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../customer/presentation/customer_main_shell.dart';

class AreaSelectionScreen extends ConsumerWidget {
  const AreaSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final areasAsync = ref.watch(activeAreasProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('আপনার এলাকা বেছে নিন')),
      body: areasAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('সমস্যা হয়েছে: $err')),
        data: (areas) {
          if (areas.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'এখনো কোনো এলাকা যোগ করা হয়নি।\nAdmin-কে জানান।',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: areas.length,
            itemBuilder: (context, index) {
              final area = areas[index];
              return InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () async {
                  final user = ref.read(supabaseUserProvider);
                  if (user == null) return;
                  
                  try {
                    await ref.read(userRepositoryProvider).updateArea(user.id, area.id);
                    // Refresh profile
                    ref.invalidate(currentUserProvider);
                    if (context.mounted) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => CustomerMainShell()),
                        (route) => false,
                      );
                    }
                  } catch (e) {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(Icons.location_on_rounded,
                            color: AppColors.primary),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(area.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15)),
                            const SizedBox(height: 3),
                            Text(
                              'ডেলিভারি ₹${area.deliveryCharge.toInt()} • ন্যূনতম ₹${area.minimumOrder.toInt()} • ${area.estimatedDeliveryMinutes} মিনিট',
                              style: TextStyle(
                                  color: AppColors.muted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios,
                          size: 14, color: AppColors.muted.withValues(alpha: 0.5)),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
