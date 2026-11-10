import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../data/seed_data.dart';
import '../pages/group_page.dart';

/// 闹市 Tab — 岛屿社群 + 同好酒馆
/// 对应 H5 renderBazaar：6 群入口 + 红点
class BazaarTab extends StatelessWidget {
  const BazaarTab({super.key});

  @override
  Widget build(BuildContext context) {
    final islandGroups = groups.where((g) => g.cat == 'island').toList();
    final clubGroups = groups.where((g) => g.cat == 'club').toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('岛屿社群 · Island Crews'),
          ...islandGroups.map((g) => _GroupItem(group: g, onTap: () => _openGroup(context, g))),
          const _SectionTitle('同好酒馆 · Taverns'),
          ...clubGroups.map((g) => _GroupItem(group: g, onTap: () => _openGroup(context, g))),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                '点击群名进入社群 · 与船员们交流',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.sub,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openGroup(BuildContext context, Group g) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => GroupPage(groupId: g.id)));
  }
}

/// H5 .section-title — flex 居中，两侧渐变线，金色 Cinzel 字体
class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
      child: Row(
        children: [
          Expanded(child: _gradientLine()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: 'Cinzel',
                fontSize: 12,
                letterSpacing: 3,
                color: AppColors.gold,
              ),
            ),
          ),
          Expanded(child: _gradientLine()),
        ],
      ),
    );
  }

  Widget _gradientLine() => Container(
        height: 1,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Color(0x00E8B84A),
              AppColors.goldHalf,
              Color(0x00E8B84A),
            ],
            stops: [0, 0.5, 1],
          ),
        ),
      );
}

/// H5 .grp-item — flex 行，avatar + body + badge
class _GroupItem extends StatelessWidget {
  final Group group;
  final VoidCallback onTap;
  const _GroupItem({required this.group, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              children: [
                // .grp-avatar 46×46 圆角12 渐变 135deg ocean→#0F6E56
                Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF123A6B), Color(0xFF0F6E56)],
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(group.avatar, style: const TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 12),
                // .grp-body flex:1
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // .grp-head space-between
                      Row(
                        children: [
                          // .grp-name 14px 500 #EAF2FF ellipsis
                          Expanded(
                            child: Text(
                              group.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFFEAF2FF),
                              ),
                            ),
                          ),
                          // .grp-time 11px sub margin-left:8
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Text(
                              group.time,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.sub,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      // .grp-last 12px sub ellipsis
                      Text(
                        group.last,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.sub,
                        ),
                      ),
                    ],
                  ),
                ),
                // .grp-badge coral 圆点
                if (group.badge > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    constraints: const BoxConstraints(minWidth: 20),
                    height: 20,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: AppColors.coral,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      group.badge > 99 ? '99+' : '${group.badge}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
