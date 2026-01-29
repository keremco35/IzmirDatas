# 🚌 IzmirDatas

<p align="center">
  <img src="https://img.shields.io/badge/Platform-iOS%2015%2B-blue?style=for-the-badge&logo=apple" alt="iOS 15+" />
  <img src="https://img.shields.io/badge/Swift-5.9-orange?style=for-the-badge&logo=swift" alt="Swift 5.9" />
  <img src="https://img.shields.io/badge/License-GPL%20v3-green?style=for-the-badge" alt="License" />
  <img src="https://img.shields.io/badge/CI-GitHub%20Actions-2088FF?style=for-the-badge&logo=github-actions" alt="CI" />
</p>

<p align="center">
  <strong>İzmir'deki ESHOT otobüslerini gerçek zamanlı takip eden modern bir iOS uygulaması</strong>
</p>

---

## 📱 Özellikler

- 🗺️ **Canlı Harita** - Otobüslerin anlık konumlarını haritada görüntüleme
- 🚏 **Durak Bilgileri** - Tüm ESHOT duraklarını arama ve görüntüleme
- 🛤️ **Hat Listesi** - Tüm otobüs hatlarını görüntüleme
- 📅 **Sefer Saatleri** - Hafta içi, Cumartesi ve Pazar günleri için hareket saatleri
- 💾 **Çevrimdışı Destek** - Veriler önbelleğe alınarak internet olmadan da erişim
- ♿ **Erişilebilirlik** - Engelli aparatı, bisiklet rafı ve elektrikli otobüs bilgileri

## 🛠️ Teknolojiler

| Kategori | Teknoloji |
|----------|-----------|
| **Platform** | iOS 15+ |
| **Dil** | Swift 5.9 |
| **UI Framework** | SwiftUI |
| **Harita** | MapKit |
| **Veri Kaynağı** | [İzmir Açık Veri Portalı (CKAN API)](https://acikveri.bizizmir.com) |
| **Önbellek** | Core Data |
| **Linting** | SwiftLint |
| **CI/CD** | GitHub Actions |

## 📊 Veri Kaynakları

Uygulama, İzmir Büyükşehir Belediyesi Açık Veri Portalı'ndan aşağıdaki veri setlerini kullanır:

| Veri Seti | Açıklama | TTL |
|-----------|----------|-----|
| `eshot-otobus-hat-listesi` | Otobüs hat listesi | 24 saat |
| `eshot-otobus-duraklari` | Otobüs durakları | 12 saat |
| `otobus-hareket-saatleri` | Hareket saatleri | 12 saat |
| `hatta-ait-otobuslerin-anlik-konum-bilgileri` | Anlık konum | Gerçek zamanlı |

## 🚀 Kurulum

### Gereksinimler

- macOS 13.0+
- Xcode 15.0+
- iOS 15.0+ cihaz veya simülatör

### Adımlar

1. **Repository'yi klonlayın:**
   ```bash
   git clone https://github.com/keremco35/IzmirDatas.git
   cd IzmirDatas
   ```

2. **Xcode ile projeyi açın:**
   ```bash
   open IzmirDatas.xcodeproj
   ```

3. **Uygulamayı çalıştırın:**
   - Hedef cihazı seçin (iPhone Simulator veya gerçek cihaz)
   - `Cmd + R` tuşlarına basın

## 🧪 Test

### Testleri Çalıştırma

```bash
xcodebuild test \
  -project IzmirDatas.xcodeproj \
  -scheme IzmirDatas \
  -destination "platform=iOS Simulator,name=iPhone 16" \
  CODE_SIGNING_ALLOWED=NO
```

### SwiftLint

```bash
# SwiftLint kurulumu (macOS)
brew install swiftlint

# Lint çalıştırma
swiftlint lint
```

## 📁 Proje Yapısı

```
IzmirDatas/
├── .github/
│   └── workflows/
│       └── ios-ci.yml        # CI/CD konfigürasyonu
├── Config/                    # Yapılandırma dosyaları
├── IzmirDatas/
│   ├── IzmirDatasApp.swift   # Uygulama giriş noktası
│   ├── ContentView.swift      # Ana içerik görünümü
│   ├── DataLayer.swift        # API istemcisi ve veri modelleri
│   ├── LiveMapView.swift      # Canlı harita görünümü
│   ├── RoutesView.swift       # Hat listesi görünümü
│   ├── StopsView.swift        # Duraklar görünümü
│   ├── TimetableView.swift    # Sefer saatleri görünümü
│   └── Persistence.swift      # Core Data yönetimi
├── IzmirDatasTests/           # Birim testleri
├── IzmirDatasUITests/         # UI testleri
├── .swiftlint.yml             # SwiftLint kuralları
├── Gemfile                    # Ruby bağımlılıkları (Fastlane)
├── fastlane/                  # Fastlane konfigürasyonu
└── LICENSE                    # GPL v3 lisansı
```

## 🔄 CI/CD

Proje, GitHub Actions ile otomatik olarak:

| İş | Açıklama | Tetikleyici |
|----|----------|-------------|
| **SwiftLint** | Kod kalitesi kontrolü | Her push/PR |
| **Build & Test** | Derleme ve test | Her push/PR |
| **Archive & IPA** | IPA oluşturma | `main` branch push |

### Manuel Tetikleme

Workflow'u manuel olarak tetiklemek için GitHub Actions sekmesinden `workflow_dispatch` kullanabilirsiniz.

## 📐 Mimari

```
┌─────────────────────────────────────────────────────────┐
│                     SwiftUI Views                        │
│  (ContentView, LiveMapView, RoutesView, StopsView, ...)  │
├─────────────────────────────────────────────────────────┤
│                  DatasetsRepository                      │
│         (Cache Management, Data Transformation)          │
├─────────────────────────────────────────────────────────┤
│     CKANResolver          │         APIClient            │
│  (Dynamic URL Discovery)  │    (HTTP Requests)           │
├─────────────────────────────────────────────────────────┤
│                   PersistenceController                  │
│                      (Core Data)                         │
├─────────────────────────────────────────────────────────┤
│               İzmir Açık Veri Portalı                    │
│             (acikveri.bizizmir.com)                      │
└─────────────────────────────────────────────────────────┘
```

## 🤝 Katkıda Bulunma

Katkılarınızı memnuniyetle karşılıyoruz! Lütfen aşağıdaki adımları takip edin:

1. Bu repository'yi fork edin
2. Yeni bir branch oluşturun (`git checkout -b feature/yeni-ozellik`)
3. Değişikliklerinizi commit edin (`git commit -m 'Yeni özellik eklendi'`)
4. Branch'inizi push edin (`git push origin feature/yeni-ozellik`)
5. Pull Request oluşturun

### Kod Standartları

- SwiftLint kurallarına uyun
- Türkçe commit mesajları tercih edilir
- Yeni özellikler için birim testleri ekleyin

## 📄 Lisans

Bu proje **GNU General Public License v3.0** altında lisanslanmıştır. Detaylar için [LICENSE](LICENSE) dosyasına bakın.

## 👤 İletişim

**Kerem** - [@keremco35](https://github.com/keremco35)

---

<p align="center">
  <sub>İzmir'de 🚌 ile yapıldı</sub>
</p>
