# 支付宝 SDK keep 规则（来自支付宝官方 App 支付接入文档，随 tobias 插件接入补齐）。
# 当前 release 未开启 minify 时无实际作用；未来若开启 R8 混淆，此文件兜底
# 保证 PayTask 反射调用链不被裁剪（插件自带的 consumer proguard 已被清空，
# 见 android/build.gradle.kts 中 tobias 兼容补丁）。

-keep class com.alipay.android.app.IAlixPay{*;}
-keep class com.alipay.android.app.IAlixPay$Stub{*;}
-keep class com.alipay.android.app.IRemoteServiceCallback{*;}
-keep class com.alipay.android.app.IRemoteServiceCallback$Stub{*;}
-keep class com.alipay.sdk.app.PayTask{ public *;}
-keep class com.alipay.sdk.app.AuthTask{ public *;}
-keep class com.alipay.sdk.app.H5PayCallback {
    <fields>;
    <methods>;
}
-keep class com.alipay.android.phone.mrpc.core.** { *; }
-keep class com.alipay.mobile.framework.service.annotation.** { *; }
-keep class com.ta.utdid2.** { *;}
-keep class com.ut.device.** { *;}
-keepclasseswithmembernames class * {
    native <methods>;
}
