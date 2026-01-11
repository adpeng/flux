import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/v2board_api.dart';
import '../models/invite_data.dart';
import '../theme/app_colors.dart';
import '../widgets/flux_loader.dart';
import 'package:share_plus/share_plus.dart';

class InviteScreen extends StatefulWidget {
  const InviteScreen({super.key});

  @override
  State<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<InviteScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  bool _isGenerating = false;
  InviteFetchData? _inviteData;
  List<InviteDetail> _details = [];
  late AnimationController _animController;
  late Animation<double> _breatheAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _breatheAnim = Tween<double>(begin: 0.2, end: 0.8).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
    
    _loadData();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final api = V2BoardApi();
      final data = await api.fetchInviteData();
      final details = await api.fetchInviteDetails();
      if (mounted) {
        setState(() {
          _inviteData = data;
          _details = details;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载失败: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _generateCode() async {
    setState(() => _isGenerating = true);
    try {
      final api = V2BoardApi();
      await api.generateInviteCode();
      await _loadData(); // Reload data to show new code
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('生成失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('邀请管理'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: FluxLoader())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_inviteData != null) _buildStatsGrid(_inviteData!.stat),
                    const SizedBox(height: 24),
                    _buildSectionHeader('我的邀请码'),
                    const SizedBox(height: 12),
                    if (_inviteData != null) _buildCodesList(_inviteData!.codes),
                    const SizedBox(height: 16),
                    _buildGenerateButton(),
                    const SizedBox(height: 32),
                    _buildSectionHeader('邀请记录'),
                    const SizedBox(height: 12),
                    _buildDetailsList(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  Widget _buildStatsGrid(InviteStat stat) {
    return AnimatedBuilder(
      animation: _breatheAnim,
      builder: (context, child) {
        final shadowOpacity = 0.1 + (_breatheAnim.value * 0.15); // 0.1 -> 0.25
        final borderOpacity = 0.2 + (_breatheAnim.value * 0.3); // 0.2 -> 0.5
        final blurRadius = 10.0 + (_breatheAnim.value * 15.0); // 10 -> 25

        return Column(
          children: [
            // 1. Financial Card (Black/Silver breathing) - Compact Horizontal Layout
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              decoration: BoxDecoration(
                // Dark Metallic Gradient
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF2B2E36), // Lighter metallic
                    Color(0xFF15171C), // Deep dark
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.accent.withOpacity(borderOpacity),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withOpacity(shadowOpacity),
                    blurRadius: blurRadius,
                    spreadRadius: 1,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left Side: Label + Big Amount
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       Row(
                         children: [
                           Container(
                             padding: const EdgeInsets.all(6),
                             decoration: BoxDecoration(
                               color: Colors.white.withOpacity(0.05),
                               borderRadius: BorderRadius.circular(8),
                               border: Border.all(color: Colors.white.withOpacity(0.1)),
                             ),
                             child: const Icon(Icons.account_balance_wallet_outlined, color: AppColors.accent, size: 14),
                           ),
                           const SizedBox(width: 8),
                           Text(
                            '可用佣金',
                            style: TextStyle(
                              color: AppColors.accent.withOpacity(0.8),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '¥${stat.availableCommission}',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                          shadows: [
                            Shadow(
                              color: Colors.black,
                              blurRadius: 10,
                              offset: Offset(0, 2),
                            )
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Divider
                  Container(
                    width: 1,
                    height: 50,
                    color: AppColors.accent.withOpacity(0.1),
                  ),

                  // Right Side: Compact Stats Column
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildMiniStat('确认中', '¥${stat.pendingCommission}'),
                      const SizedBox(height: 12),
                      _buildMiniStat('历史总计', '¥${stat.validCommission}'),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // 2. Performance Card (Subtle breathing)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF0F1014), // Darker surface
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.accent.withOpacity(borderOpacity * 0.5), // Subtle border
                ),
                boxShadow: [
                  BoxShadow(
                     color: Colors.black.withOpacity(0.5),
                     blurRadius: 10,
                     offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildPerformanceItem(
                    Icons.people_outline_rounded,
                    '${stat.registeredUsers}',
                    '注册用户',
                  ),
                  Container(width: 1, height: 32, color: AppColors.accent.withOpacity(0.1)),
                  _buildPerformanceItem(
                    Icons.percent_rounded,
                    '${stat.commissionRate}%',
                    '佣金比例',
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMiniStat(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.accent.withOpacity(0.5),
            fontSize: 11,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildPerformanceItem(IconData icon, String value, String label) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.accent.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.accent, size: 18),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: AppColors.accent.withOpacity(0.4),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );
  }



  Widget _buildCodesList(List<InviteCode> codes) {
    if (codes.isEmpty) {
      return Center(
        child: Text(
          '暂无邀请码',
          style: TextStyle(color: Colors.white.withOpacity(0.5)),
        ),
      );
    }
    return Column(
      children: codes.map((code) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.accent.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    code.code,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.accent,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '创建于: ${_formatDate(code.createdAt)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.4),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                   IconButton(
                    onPressed: () {
                      final url = 'https://fluxhub.lol/#/register?code=${code.code}';
                      Share.share('Check out Flux VPN! $url');
                    },
                    icon: const Icon(Icons.share, color: Colors.white70),
                  ),
                  IconButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: code.code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('已复制到剪贴板')),
                      );
                    },
                    icon: const Icon(Icons.copy, color: Colors.white70),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildGenerateButton() {
    return AnimatedBuilder(
      animation: _breatheAnim,
      builder: (context, child) {
        return GestureDetector(
          onTap: _isGenerating ? null : _generateCode,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              // Silver Gradient
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFE5E6EB), // Bright Silver
                  Color(0xFF9CA3AF), // Metallic Grey
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: _breatheAnim.value * 0.3),
                  blurRadius: 15 + (_breatheAnim.value * 10),
                  spreadRadius: _breatheAnim.value * 2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: Center(
        child: _isGenerating
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.black, // Dark loader on silver
                ),
              )
            : const Text(
                '生成邀请码',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.black, // Black text on silver
                ),
              ),
      ),
    );
  }

  Widget _buildDetailsList() {
    if (_details.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            '暂无记录',
            style: TextStyle(color: Colors.white.withOpacity(0.5)),
          ),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _details.length,
      itemBuilder: (context, index) {
        final item = _details[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getCommissionStatusText(item.commissionStatus),
                    style: TextStyle(
                      color: _getCommissionStatusColor(item.commissionStatus),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(item.createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.4),
                    ),
                  ),
                ],
              ),
              Text(
                '+${item.commissionBalance}元',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _getCommissionStatusText(int status) {
    switch (status) {
      case 0: return '待确认';
      case 1: return '发放中';
      case 2: return '有效';
      case 3: return '无效';
      default: return '未知';
    }
  }

  Color _getCommissionStatusColor(int status) {
    switch (status) {
      case 0: return Colors.orange;
      case 1: return Colors.blue;
      case 2: return Colors.green;
      case 3: return Colors.red;
      default: return Colors.grey;
    }
  }
}
