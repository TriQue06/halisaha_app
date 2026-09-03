import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../services/ad_service.dart';

/// Uyarlanabilir (adaptive) banner reklam yuvası.
///
/// Reklam yüklenene kadar **hiç yer kaplamaz**; böylece liste açılırken
/// boş bir gri şerit görünmez ve içerik zıplamaz. Yükleme başarısız
/// olursa da kalıcı olarak gizli kalır.
///
/// Yerleşim kuralı: yalnızca göz gezdirme ekranlarında kullanılır.
/// Maç teklifi, iletişim bilgisi ve arama butonlarının bulunduğu
/// ekranlara konmaz — hem kullanıcı güveni hem AdMob'un "tıklanabilir
/// öğeye bitişik reklam" yasağı nedeniyle.
class BannerAdSlot extends StatefulWidget {
  const BannerAdSlot({super.key, this.padding = const EdgeInsets.only(top: 8)});

  final EdgeInsets padding;

  @override
  State<BannerAdSlot> createState() => _BannerAdSlotState();
}

class _BannerAdSlotState extends State<BannerAdSlot> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ad == null) _load();
  }

  Future<void> _load() async {
    // Ekran genişliğine uyan banner boyutu; sabit 320x50'den daha iyi
    // doluluk ve gelir veriyor.
    final AnchoredAdaptiveBannerAdSize? size =
        await AdSize.getLargeAnchoredAdaptiveBannerAdSize(
      MediaQuery.of(context).size.width.truncate(),
    );
    if (size == null || !mounted) return;

    final BannerAd ad = BannerAd(
      adUnitId: AdService.bannerUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          ad.dispose();
          if (mounted) setState(() => _ad = null);
        },
      ),
    );

    _ad = ad;
    await ad.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final BannerAd? ad = _ad;
    if (ad == null || !_loaded) return const SizedBox.shrink();

    return Padding(
      padding: widget.padding,
      child: Center(
        child: SizedBox(
          width: ad.size.width.toDouble(),
          height: ad.size.height.toDouble(),
          child: AdWidget(ad: ad),
        ),
      ),
    );
  }
}
