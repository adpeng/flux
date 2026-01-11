import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/app_header.dart';
import '../widgets/animated_card.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const AppHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Expanded(
                          child: Center(
                            child: Text(
                              '隐私政策',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 48), // Balance the icon button
                      ],
                    ),
                    const SizedBox(height: 24),
                    AnimatedCard(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          _SectionTitle('1. 我们收集的信息'),
                          _SectionText(
                            '为了提供 VPN 连接服务，我们需要收集极少量的必要信息：\n'
                            '• 您的账户信息（仅用于身份验证）\n'
                            '• 流量使用统计（用于计算配额）\n'
                            '• 连接时间戳（仅用于故障排查）\n\n'
                            '我们严格遵守"无日志"政策，绝不会记录：\n'
                            '• 您访问的网站\n'
                            '• DNS 查询记录\n'
                            '• 您的真实 IP 地址\n'
                            '• 任何传输的数据内容',
                          ),
                          SizedBox(height: 24),
                          _SectionTitle('2. 信息使用'),
                          _SectionText(
                            '我们收集的信息仅用于：\n'
                            '• 维持服务的正常运行\n'
                            '• 处理客户支持请求\n'
                            '• 防止服务被滥用',
                          ),
                          SizedBox(height: 24),
                          _SectionTitle('3. 数据安全'),
                          _SectionText(
                            '我们采用行业标准的加密技术（TLS/AES-256）保护您的数据传输。'
                            '所有的服务器均经过安全加固，确保即便在物理层面也无法被轻易入侵。',
                          ),
                          SizedBox(height: 24),
                          _SectionTitle('4. 第三方服务'),
                          _SectionText(
                            '本应用可能包含第三方 SDK（如支付网关），它们可能会收集必要的设备信息以完成交易。'
                            '我们不会主动向任何第三方出售您的个人信息。',
                          ),
                          SizedBox(height: 24),
                          _SectionTitle('5. 政策更新'),
                          _SectionText(
                            '我们可能会不时更新本隐私政策。重大变更将会通过应用内通知告知您。'
                            '继续使用本服务即表示您同意受修订后的隐私政策约束。',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _SectionText extends StatelessWidget {
  final String text;
  const _SectionText(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 14,
          height: 1.6,
        ),
      ),
    );
  }
}
