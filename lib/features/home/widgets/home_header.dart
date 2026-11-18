import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../ui/widgets/brand_mark.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
    this.loading = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final search = _SearchField(
          controller: controller,
          focusNode: focusNode,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          onClear: onClear,
          loading: loading,
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const BrandMark(),
                  const Spacer(),
                  const _SourceBadge(),
                ],
              ),
              const SizedBox(height: 18),
              search,
            ],
          );
        }

        return Row(
          children: [
            const BrandMark(),
            const Spacer(),
            SizedBox(width: 420, child: search),
            const SizedBox(width: 14),
            const _SourceBadge(),
          ],
        );
      },
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
    required this.loading,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          textInputAction: TextInputAction.search,
          style: const TextStyle(
            fontFamily: AppFonts.body,
            fontSize: 14,
            color: AppColors.text,
          ),
          cursorColor: AppColors.accentBright,
          decoration: InputDecoration(
            hintText: 'поиск по названию',
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            suffixIcon: loading
                ? const Padding(
                    padding: EdgeInsets.all(15),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : (value.text.isNotEmpty
                      ? IconButton(
                          tooltip: 'очистить',
                          onPressed: onClear,
                          icon: const Icon(Icons.close_rounded, size: 18),
                        )
                      : null),
          ),
        );
      },
    );
  }
}

class _SourceBadge extends StatelessWidget {
  const _SourceBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accent,
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.8),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
          const SizedBox(width: 7),
          const Text(
            'anilibria',
            style: TextStyle(
              fontFamily: AppFonts.body,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textSoft,
            ),
          ),
        ],
      ),
    );
  }
}
