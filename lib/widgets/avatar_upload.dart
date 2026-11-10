import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/cloud_api.dart';
import '../services/image_pipeline.dart';
import '../services/media_rules.dart';
import '../theme/colors.dart';
import 'alert_toast.dart';
import 'avatar_crop_page.dart';

/// 头像上传全流程（v2.9.5 船长页逻辑抽取，v2.9.6 供编辑资料页复用）：
/// 相册选图 → 原始文件 >10MB 拦截 → 1:1 裁剪 → 压缩（长边1024/0.8/jpg）
/// → OSS put-sign 直传 → POST /api/user/profile（后端 HEAD 二次校验 +
/// Green 图片审核，违规 403 不落库）→ 返回新头像 OSS key。
///
/// 返回 null = 用户取消/流程中止（静默）；抛出/失败已在本函数内弹统一 Toast。
Future<String?> uploadAvatarFlow(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  void snack(String msg) {
    messenger.showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white70, fontSize: 13)),
      backgroundColor: AppColors.cardSolid,
      behavior: SnackBarBehavior.floating,
    ));
  }

  try {
    // 1. 相册选图
    final XFile? picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return null;

    // 2. 原始文件大小前置拦截（不进入裁剪/压缩流程）—— v2.9.5 醒目 Toast 规范
    final Uint8List raw = await picked.readAsBytes();
    if (raw.length > MediaRules.imageMaxBytes) {
      if (!context.mounted) return null;
      showAlertToast(context, '图片文件过大，请选择不超过10MB的图片');
      return null;
    }

    // 3. 正方形裁剪（1:1）
    if (!context.mounted) return null;
    final List<int>? cropped =
        await Navigator.of(context).push<List<int>>(
      MaterialPageRoute(builder: (_) => AvatarCropPage(bytes: raw)),
    );
    if (cropped == null || cropped.isEmpty) return null;

    // 4. 压缩（长边 1024 / 0.8 / jpg）
    final Uint8List out = await compressAvatarBytes(Uint8List.fromList(cropped));

    snack('头像上传中…');
    // 5. OSS 直传（put-sign：服务端校验 ext/size 声明，key 服务端生成）
    final String key = await CloudApi.instance.uploadImage(out, ext: 'jpg');

    // 6. 提交 profile：后端 HEAD 二次校验 + Green 图片审核，通过才落库
    final r = await CloudApi.instance.updateProfile(avatar: key);
    return r.avatar ?? key;
  } on ApiException catch (e) {
    // v2.9.5 统一规范：图片上传类报错用「醒目 Toast」；流程终止不更新本地头像
    if (!context.mounted) return null;
    showAlertToast(
      context,
      e.message.contains('安全审核') ? '头像未通过安全审核，请更换图片后重试' : e.message,
    );
    return null;
  } catch (_) {
    if (context.mounted) showAlertToast(context, '头像更新失败，请检查网络后重试');
    return null;
  }
}
