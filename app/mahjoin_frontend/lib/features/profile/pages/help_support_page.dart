import 'package:flutter/material.dart';
import '../../../core/design/tokens.dart';

class HelpSupportPage extends StatelessWidget {
  const HelpSupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('幫助與支援')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: const [
          _FaqCard(
            question: '如何讓其他玩家看到我？',
            answer: '請到地圖頁點擊右下角廣播按鈕，開啟後附近玩家即可看到你。',
          ),
          SizedBox(height: 10),
          _FaqCard(
            question: '為什麼我看不到附近玩家？',
            answer: '請先確認定位權限、網路連線，以及是否在有玩家活動的區域。',
          ),
          SizedBox(height: 10),
          _FaqCard(
            question: '我可以建立私人房間嗎？',
            answer: '可以，建立房間時關閉「公開房間」即可。',
          ),
          SizedBox(height: 10),
          _FaqCard(
            question: '如何回報問題？',
            answer: '請將操作步驟與截圖提供給管理員，或聯繫 support@mahjoin.app。',
          ),
        ],
      ),
    );
  }
}

class _FaqCard extends StatelessWidget {
  final String question;
  final String answer;

  const _FaqCard({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lg,
        border: Border.all(color: AppColors.divider),
      ),
      child: ExpansionTile(
        title: Text(question, style: AppTypography.labelLarge),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              answer,
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
