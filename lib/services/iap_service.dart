import 'dart:async';
import 'dart:io' show Platform;

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';

/// 苹果 IAP 服务（仅 iOS 调用；Android 不碰本类——支付宝链路完全独立）。
///
/// ⚠️ StoreKit1 回退：in_app_purchase 3.x iOS 默认 StoreKit2，其
/// verificationData 是 JWS 交易串；后端走经典 verifyReceipt 验签接口，
/// 需要 SK1 base64 收据 → 首次使用前必须 enableStoreKit1()。
/// 该调用必须在 InAppPurchase.instance 首次访问之前执行。
class IapService {
  IapService._();

  static final IapService instance = IapService._();

  /// 支持档位（与后端 APPLE 白名单、安卓支付宝档位一一对应：1/6/30/68/198 元）
  /// ⚠️ 产品 ID 以 App Store Connect 实际配置为准（无点号 supportN，2026-11-23 更新）
  static const Set<String> productIds = {
    'support1', 'support6', 'support30', 'support68', 'support198',
  };

  /// 档位金额 → 产品 ID（reward_sheet iOS 分支用；tier 为元整数值）
  static String productIdForTier(int tier) => 'support$tier';

  bool _storeKit1Enabled = false;

  /// 首次使用前配置（幂等）：StoreKit1 回退。必须在任何 InAppPurchase.instance 访问之前。
  Future<void> ensureConfigured() async {
    if (_storeKit1Enabled || !Platform.isIOS) return;
    InAppPurchaseStoreKitPlatform.enableStoreKit1();
    _storeKit1Enabled = true;
  }

  InAppPurchase get _iap => InAppPurchase.instance;

  /// 商店是否可用（iOS 沙盒/正式环境均返回 true；模拟器无 App Store 可能 false）
  Future<bool> isAvailable() async {
    await ensureConfigured();
    return _iap.isAvailable();
  }

  /// 购买更新流（未完成交易会在订阅后重新投递——自然承接恢复购买/补单）
  Stream<List<PurchaseDetails>> get purchaseStream {
    return _iap.purchaseStream;
  }

  /// 查询档位商品（ASC 配置了 support.1~support.198 后返回非空）
  Future<List<ProductDetails>> queryProducts() async {
    await ensureConfigured();
    final res = await _iap.queryProductDetails(productIds);
    return res.productDetails;
  }

  /// 拉起苹果购买（消耗型商品；结果经 purchaseStream 异步回调）
  Future<void> buy(ProductDetails productDetails) async {
    await _iap.buyConsumable(purchaseParam: PurchaseParam(productDetails: productDetails));
  }

  /// 恢复购买（触发系统恢复流程；结果同样经 purchaseStream 回调）
  Future<void> restore() async {
    await _iap.restorePurchases();
  }

  /// 完成交易（验签通过后必须调用，否则交易会反复重新投递）
  Future<void> complete(PurchaseDetails purchase) async {
    if (purchase.pendingCompletePurchase) {
      await _iap.completePurchase(purchase);
    }
  }
}
