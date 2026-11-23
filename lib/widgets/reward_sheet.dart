import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:tobias/tobias.dart';

import '../services/cloud_api.dart';
import '../services/iap_service.dart';
import '../services/session_store.dart';
import '../theme/colors.dart';

/// 支持开发者金额面板（开服公告页「支持开发者」按钮唤起，AGENTS.md §13.12 术语规范）
/// 定位：用户自愿小额支持，非商品交易——不对应任何商品/服务/功能/权益/曝光加成；
/// 支付成功仅发放一枚电子纪念徽章（纯纪念装饰）
/// 档位固定 5 档：1 / 6 / 30 / 68 / 198（无自定义输入，后端白名单硬校验同款档位）
/// 确认 → POST /api/pay/reward 预下单（§13 契约）→ 直接拉起支付（无二次确认弹窗）
///       → 轮询查单：PAID → 「感谢支持」toast（2s，不跳转）；CLOSED/超时 → 静默关闭；
///         下单/网络异常 → 「支付未完成，请重试」（保留当前选中档位）
Future<void> showRewardSheet(BuildContext context) async {
  // 赞助下单需登录（authRequired）；登录闸门已前置在 announcement_page._onRewardTap
  if (!SessionStore.instance.hasToken) {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.cardSolid,
        title: const Text('需要登船',
            style: TextStyle(color: AppColors.goldBright, fontSize: 17, fontWeight: FontWeight.w800)),
        content: const Text('登录后即可支持开发者，支持大蓝海继续航行',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('好的', style: TextStyle(color: AppColors.gold)),
          ),
        ],
      ),
    );
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.cardSolid,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => const RewardSheet(),
  );
}

class RewardSheet extends StatefulWidget {
  const RewardSheet({super.key});

  @override
  State<RewardSheet> createState() => _RewardSheetState();
}

class _RewardSheetState extends State<RewardSheet> {
  /// 固定档位（元）——后端 REWARD_TIERS / APPLE IAP 白名单同款，三端硬约束一致
  static const List<double> _tiers = [1, 6, 30, 68, 198];

  int? _selectedTier;
  bool _submitting = false;
  String? _error;
  Timer? _pollTimer;
  int _pollCount = 0;

  // ── Apple IAP（仅 iOS 使用；Android 不触碰以下三个字段）──
  StreamSubscription<List<PurchaseDetails>>? _iapSub;
  String? _pendingAppleOrderNo; // 本次购买对应的本地 UNPAID 单号（verify 强校验用）
  bool _iapRestoring = false;   // 「恢复购买」进行中

  /// 当前选中档位金额（无自定义输入，仅固定档位）
  String? get _effectiveAmount =>
      _selectedTier == null ? null : _tiers[_selectedTier!].toStringAsFixed(2);

  /// 是否可提交（面板初始化无默认选中档位）
  bool get _canSubmit => _selectedTier != null;

  @override
  void initState() {
    super.initState();
    if (Platform.isIOS) {
      _initIap();
    }
  }

  /// iOS：先 StoreKit1 回退配置，再订阅购买更新流。
  /// 未完成（未 complete）的历史交易会在订阅后自动重新投递 → 承接恢复购买/补单。
  Future<void> _initIap() async {
    await IapService.instance.ensureConfigured();
    _iapSub = IapService.instance.purchaseStream.listen(
      _handleIapUpdates,
      onError: (Object e) => debugPrint('[reward] IAP 流异常: $e'),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _iapSub?.cancel();
    super.dispose();
  }

  /// 最终校验：必须选中档位（档位金额均在前端固定列表 + 后端白名单内）
  String? _validate(String? amount) {
    if (amount == null || amount.isEmpty) return '请选择金额';
    return null;
  }

  Future<void> _submit() async {
    final amount = _effectiveAmount;
    final err = _validate(amount);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _error = null;
      _submitting = true;
    });
    try {
      if (Platform.isIOS) {
        await _submitAppleIap();
        return;
      }
      final order = await CloudApi.instance.createRewardOrder(amount!);
      if (!mounted) return;
      // 原生拉起支付宝 App（alipay.trade.app.pay）：仅 Android 调用 tobias 插件；
      // iOS 分支不走支付宝、不调用该插件（§13 支付契约）
      if (!Platform.isAndroid) {
        setState(() {
          _submitting = false;
          _error = '当前系统暂不支持在线支付';
        });
        return;
      }
      final payResult = await Tobias().pay(order.orderString);
      if (!mounted) return;
      // 插件回调仅决定是否进入轮询，订单状态权威来源是后端 notify 回调改库（§13）：
      // 9000=支付成功 8000=处理中（如确认中，仍需查单核实）→ 轮询；
      // 6001=用户取消 4000=失败/未装支付宝 6002=网络错误 → 「支付未完成，请重试」
      // （订单已创建 UNPAID，换设备支付也能正常到账，notify 回调兜底）
      final resultStatus = payResult['resultStatus']?.toString();
      if (resultStatus != '9000' && resultStatus != '8000') {
        debugPrint('[reward] 原生支付未完成 resultStatus=$resultStatus');
        setState(() {
          _submitting = false;
          _error = '支付未完成，请重试';
        });
        return;
      }
      await _pollOrderStatus(order.outTradeNo);
    } on PlatformException catch (e) {
      // 唤起支付失败（插件异常等）。注意：订单已创建（UNPAID），
      // 支付宝侧同样存在该交易——用户换设备支付也能正常到账（notify 回调兜底）
      debugPrint('[reward] 唤起支付异常: $e');
      if (!mounted) return;
      // 文案规范：不出现支付渠道名，统一「支付未完成」
      setState(() {
        _submitting = false;
        _error = '支付未完成，请重试';
      });
    } catch (e) {
      if (!mounted) return;
      // 调试输出（debug 包 logcat 可见，release 包无影响）
      debugPrint('[reward] 下单异常: $e');
      setState(() {
        _submitting = false;
        _error = e is ApiException ? e.message : '下单失败，请稍后重试';
      });
    }
  }

  // ══════════ Apple IAP 链路（仅 iOS 执行）══════════════════
  // 流程：本地下单（UNPAID）→ StoreKit buyConsumable 拉起苹果支付 →
  // purchaseStream 回调拿收据 → POST /api/pay/apple/verify 验签 →
  // PAID → completePurchase + 成功。订单状态权威来源是后端验签改库
  // + 补单轮询（苹果无异步通知），插件回调不用于判定订单状态。

  /// iOS 购买入口：建本地单 → 查商品 → 拉起苹果支付（结果走 _handleIapUpdates）
  Future<void> _submitAppleIap() async {
    final productId = IapService.productIdForTier(_tiers[_selectedTier!].toInt());
    try {
      final avail = await IapService.instance.isAvailable();
      if (!mounted) return;
      if (!avail) {
        setState(() {
          _submitting = false;
          _error = '支付服务暂不可用，请稍后重试';
        });
        return;
      }
      final order = await CloudApi.instance.createAppleIapOrder(productId);
      if (!mounted) return;
      _pendingAppleOrderNo = order.outTradeNo;
      final products = await IapService.instance.queryProducts();
      if (!mounted) return;
      ProductDetails? pd;
      for (final p in products) {
        if (p.id == productId) { pd = p; break; }
      }
      if (pd == null) {
        _pendingAppleOrderNo = null;
        setState(() {
          _submitting = false;
          _error = '支付服务暂不可用，请稍后重试';
        });
        return;
      }
      await IapService.instance.buy(pd);
      // 购买结果经 purchaseStream 异步回调（_handleIapUpdates），保持 _submitting=true
    } catch (e) {
      debugPrint('[reward] IAP 下单异常: $e');
      if (!mounted) return;
      _pendingAppleOrderNo = null;
      setState(() {
        _submitting = false;
        _error = e is ApiException ? e.message : '支付未完成，请重试';
      });
    }
  }

  /// 购买更新流处理（正常购买 / 恢复购买 / 未完成交易重推 统一入口）
  Future<void> _handleIapUpdates(List<PurchaseDetails> updates) async {
    for (final purchase in updates) {
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        await _verifyApplePurchase(purchase);
      } else if (purchase.status == PurchaseStatus.error) {
        // 用户取消/支付失败：完成交易避免反复投递，提示重试
        await IapService.instance.complete(purchase);
        debugPrint('[reward] IAP 购买未完成: ${purchase.error?.message ?? 'unknown'}');
        if (!mounted) return;
        setState(() {
          _submitting = false;
          _pendingAppleOrderNo = null;
          _error = '支付未完成，请重试';
        });
      }
      // pending（等待确认，如家长批准）：静默，面板保持 loading
    }
  }

  /// 收据上传后端验签 → PAID → completePurchase + 成功流程
  Future<void> _verifyApplePurchase(PurchaseDetails purchase) async {
    final receipt = purchase.verificationData.localVerificationData;
    if (receipt.isEmpty) {
      // 无收据无法验签：完成交易避免反复投递
      await IapService.instance.complete(purchase);
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _pendingAppleOrderNo = null;
        _error = '支付未完成，请重试';
      });
      return;
    }
    try {
      await CloudApi.instance.verifyAppleIapReceipt(
        outTradeNo: _pendingAppleOrderNo,
        receipt: receipt,
      );
      // 验签通过（订单已 PAID）：完成交易 + 成功流程
      await IapService.instance.complete(purchase);
      if (!mounted) return;
      _pendingAppleOrderNo = null;
      setState(() => _submitting = false);
      Navigator.of(context).pop();
      _showSupportThanksToast(context);
    } catch (e) {
      debugPrint('[reward] IAP 验签未通过: $e');
      // 验签失败不 complete：交易保持未完成，后端补单轮询会用留档 receipt
      // 重试验签，面板重开订阅后该交易也会自动重推补发。文案不误导成功。
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e is ApiException ? e.message : '支付结果确认中，稍后自动到账';
      });
    }
  }

  /// 「恢复购买」入口（iOS）：触发系统恢复，历史交易经 purchaseStream
  /// 重推（restored）→ 走无单号验签补单（后端按最近同商品 UNPAID 单定位）
  Future<void> _restoreIap() async {
    setState(() => _iapRestoring = true);
    try {
      await IapService.instance.restore();
    } catch (e) {
      debugPrint('[reward] IAP 恢复购买异常: $e');
      if (mounted) {
        setState(() => _error = '恢复购买未完成，请重试');
      }
    } finally {
      if (mounted) setState(() => _iapRestoring = false);
    }
  }

  /// 轮询查单（1.5s 间隔，最长 ~90s）——状态权威来源是后端 notify 回调改库（§13），轮询只是 UI 反馈。
  /// 结果流（§13.12 规范）：
  /// - PAID        → 关闭面板 + 「感谢支持」toast（2s 自动消失，不跳转徽章页，无恭喜/解锁话术）
  /// - CLOSED/超时 → 用户取消支付：静默关闭面板，无提示
  /// （下单/网络异常走 _submit 的 catch → 「支付未完成，请重试」，保留当前选中档位）
  Future<void> _pollOrderStatus(String outTradeNo) async {
    final completer = Completer<void>();
    _pollTimer?.cancel();
    _pollCount = 0;
    _pollTimer = Timer.periodic(const Duration(milliseconds: 1500), (t) async {
      _pollCount++;
      try {
        final status = await CloudApi.instance.fetchOrderStatus(outTradeNo);
        if (!mounted) {
          t.cancel();
          if (!completer.isCompleted) completer.complete();
          return;
        }
        if (status == 'PAID') {
          t.cancel();
          if (!completer.isCompleted) completer.complete();
          if (!mounted) return;
          Navigator.of(context).pop(); // 关闭金额面板
          _showSupportThanksToast(context); // 「感谢支持」2s，不跳转不弹窗
        } else if (status == 'CLOSED' || _pollCount >= 60) {
          // 用户取消支付（订单被关单/长期 UNPAID）→ 静默关闭面板，无提示
          t.cancel();
          if (!completer.isCompleted) completer.complete();
          if (!mounted) return;
          Navigator.of(context).pop();
        }
      } catch (_) {
        // 单次轮询失败忽略（网络抖动），到上限静默关闭
        if (_pollCount >= 60 && !completer.isCompleted) {
          t.cancel();
          completer.complete();
          if (mounted) Navigator.of(context).pop();
        }
      }
    });
    return completer.future;
  }

  /// 「感谢支持」成功 toast（2s 自动消失；中性金调，禁止恭喜/解锁类话术，不跳转）
  void _showSupportThanksToast(BuildContext context) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned.fill(
        child: IgnorePointer(
          child: Center(
            child: AnimatedOpacity(
              opacity: 1,
              duration: const Duration(milliseconds: 200),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.abyss.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
                ),
                child: const Text(
                  '感谢支持',
                  style: TextStyle(
                      color: AppColors.goldBright,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(entry);
    Timer(const Duration(seconds: 2), () {
      if (entry.mounted) entry.remove();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Text('支持开发者',
                  style: TextStyle(
                      color: AppColors.goldBright, fontSize: 17, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 4),
            const Center(
              child: Text('选择金额，帮助项目持续运营',
                  style: TextStyle(color: AppColors.textHint, fontSize: 12)),
            ),
            const SizedBox(height: 16),
            // 固定档位 chips
            Row(
              children: List.generate(_tiers.length, (i) {
                final selected = _selectedTier == i;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedTier = selected ? null : i;
                        _error = null;
                      });
                    },
                    child: Container(
                      margin: EdgeInsets.only(right: i == _tiers.length - 1 ? 0 : 8),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: selected ? AppColors.btnGoldGradient : null,
                        color: selected ? null : AppColors.subDark,
                        border: Border.all(
                          color: selected ? Colors.white.withValues(alpha: 0.4) : AppColors.cardBorder,
                        ),
                      ),
                      child: Text(
                        '${_tiers[i].toInt()}元',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: selected ? AppColors.goldBtnText : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Color(0xFFFF8A8A), fontSize: 12.5)),
            ],
            const SizedBox(height: 14),
            // 温馨提示（§13.12 规范：不主动提退款；iOS 端退款提示由系统/独立渲染）
            const Text(
              '温馨提示：请理性消费，未成年人请勿消费。支付成功可获得一枚电子纪念徽章，不解锁任何额外功能、权益、曝光加成。',
              style: TextStyle(color: AppColors.textHint, fontSize: 11, height: 1.5),
            ),
            // iOS 专属：恢复购买入口（IAP 无异步通知，支付未到账时手动触发补单）
            if (Platform.isIOS) ...[
              const SizedBox(height: 8),
              Center(
                child: GestureDetector(
                  onTap: _iapRestoring ? null : _restoreIap,
                  child: Text(
                    _iapRestoring ? '恢复中…' : '已支付未到账？恢复购买',
                    style: const TextStyle(
                        color: AppColors.textHint, fontSize: 11,
                        decoration: TextDecoration.underline),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            // 确认按钮双态：未选中档位置灰不可点「请选择金额」；选中「确认支持 ¥{金额}」
            // 点击直接拉起支付，无自定义二次确认弹窗
            SizedBox(
              width: double.infinity,
              height: 48,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: _canSubmit ? AppColors.btnGoldGradient : null,
                  color: _canSubmit ? null : AppColors.subDark,
                  boxShadow: _canSubmit
                      ? [
                          BoxShadow(
                            color: AppColors.copper.withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ]
                      : null,
                ),
                child: ElevatedButton(
                  onPressed: _canSubmit && !_submitting ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    disabledBackgroundColor: Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.goldBtnText))
                      : Text(
                          _canSubmit ? '确认支持 ¥${_effectiveAmount!}' : '请选择金额',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: _canSubmit
                                  ? AppColors.goldBtnText
                                  : AppColors.textHint,
                              letterSpacing: 2),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
