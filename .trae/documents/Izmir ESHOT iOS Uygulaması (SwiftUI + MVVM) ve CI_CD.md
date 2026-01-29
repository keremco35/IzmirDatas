## Uygulama (SwiftUI + MVVM)
- SwiftUI + MapKit ile 4 veri kaynağı entegrasyonu (anlık konum, hatlar, duraklar, hareket saatleri).
- MVVM: Network (URLSession) → Repository → Core Data cache → ViewModel → View.
- Hat listesi alfabetik + arama; duraklar konum/radius filtresi; saatler günlük/haftalık + gidiş/dönüş.

## Ortam Ayrımı (dev/staging/prod)
- 3 Build Configuration + Scheme (Development/Staging/Production).
- .xcconfig ile API endpoint/refresh aralığı gibi değerler.

## Testler
- Unit: URLProtocol stub, CSV parser, repository cache/TTL, ViewModel state.
- UI: hat→durak→saatler akışı ve izin senaryoları.

## GitHub Actions: macos-latest, xcodebuild ile derleme + .ipa üretimi (imzalama olmadan)
### Temel prensip
- İmzalama yok: xcodebuild çağrılarında CODE_SIGNING_ALLOWED=NO ve CODE_SIGNING_REQUIRED=NO kullanılır.
- .ipa, istenen şekilde “Payload/.app” zip’lenerek oluşturulur (install edilebilirlik hedeflenmez; sadece paket üretimi).

### Workflow tetikleri
- push + pull_request: build/test + .ipa paketleme + rapor + artifact.
- workflow_dispatch: ortam seçimi (development/staging/production) ve opsiyonel parametreler.

### Adımlar (tek job veya env matrix)
1) Checkout
- Kaynak kod çekilir.

2) Xcode seçimi (15+)
- macos-latest üzerinde Xcode 15+ path seçilir (setup-xcode ile) ve sürüm loglanır.

3) Proje tespiti
- Script: önce *.xcworkspace var mı bakılır; yoksa *.xcodeproj.
- Scheme belirleme: varsayılan “App” veya env’e göre “App-Dev/App-Staging/App”. (Onay sonrası projedeki gerçek scheme’lere göre netleştirilir.)

4) Build + Archive (xcodebuild)
- Komut: xcodebuild archive ... -destination 'generic/platform=iOS' -archivePath build/<AppName>.xcarchive
- CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
- Log: tee build/xcodebuild.log; pipefail ile hata olursa job fail.
- Hata durumunda son log satırları konsola basılır.

5) .app bulma (istenen dizin)
- build/<AppName>.xcarchive/Products/Applications/*.app bulunur.
- Bulunamazsa hata ile durdurulur.

6) Payload oluşturma + .ipa üretimi
- Payload/ oluşturulur, .app kopyalanır.
- Version/build: .app/Info.plist içinden CFBundleShortVersionString ve CFBundleVersion okunur.
- Timestamp: UTC format YYYYMMDD_HHMMSS.
- İsim: {app_name}_{version}_{build_number}_{timestamp}.ipa
- Zip: (cd staging && zip -r <name>.ipa Payload)

7) Rapor üretimi
- Boyut: stat ile byte (ve opsiyonel MB).
- SHA256: shasum -a 256.
- Çıktı yolu: tam path.
- Bu bilgiler hem log’a hem de GitHub Actions Step Summary’e yazılır; ayrıca ipa_report.txt artifact.

8) Artifact upload
- .ipa ve ipa_report.txt yüklenir.

### Hata yönetimi ve bildirim
- Her script adımı set -euo pipefail ile çalışır; herhangi bir hata derlemeyi durdurur.
- failure() koşuluyla ayrı “Notify” step’i:
  - actions/github-script ile PR’a comment (PR context varsa) veya repo’da issue oluşturma.
  - Opsiyonel: SLACK_WEBHOOK_URL secret varsa curl ile Slack bildirimi (secret yoksa step skip).

## Teslimat Çıktıları
- SwiftUI/MVVM uygulama kodu + Core Data cache + MapKit.
- Unit/UI testleri.
- macos-latest üzerinde çalışan GitHub Actions workflow’u:
  - xcodebuild archive
  - /Products/Applications içinden .app → Payload → {app_name}_{version}_{build_number}_{timestamp}.ipa
  - Başarısızlıkta durdurma + hata logu + bildirim
  - Başarıda boyut + SHA256 + çıktı yolu raporu ve artifact

## Onaydan sonra uygulama sırası
- Proje iskeleti ve scheme/config’leri oluşturma
- Data entegrasyonları + offline cache
- UI ekranları
- Testler
- Workflow ve Fastlane (ci lane) entegrasyonu, repo’daki gerçek app/scheme adlarına göre son ayar