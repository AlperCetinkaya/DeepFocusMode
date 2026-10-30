<p align="center">
  <img src="Assets/Brand/AppIconMaster.png" width="128" alt="Deep Focus Mode icon">
</p>

# Deep Focus Mode

**Keep your active window in focus. Dim the distractions.**

**Etkin penceren odakta kalsın. Dikkat dağıtan alanlar kararsın.**

[![macOS build and test](https://github.com/AlperCetinkaya/DeepFocusMode/actions/workflows/macos.yml/badge.svg)](https://github.com/AlperCetinkaya/DeepFocusMode/actions/workflows/macos.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

[English](#english) · [Türkçe](#türkçe)

## English

Deep Focus Mode is a free, open-source native macOS menu bar app that dims the area around your active window. Built with SwiftUI and AppKit, it works entirely offline and includes English and Turkish interfaces.

### Available now

- **Quick Focus:** turn dimming on or off from the menu bar or Settings.
- **Adjustable intensity:** choose dimming opacity from 0% to 85%.
- **Window tracking:** follow the active window as it moves or resizes, using public Window Server metadata and application/mouse events.
- **Rounded opening:** keep the focused window bright with rounded corners. Overlays let mouse clicks pass through and never take keyboard focus.
- **Safe startup:** dimming starts off after each launch. Unavailable window geometry removes the overlays. No Accessibility or Screen Recording permission is needed.
- **Local preferences:** remember opacity without saving window titles, screenshots, typed content or usage history.

### Status and limitations

Version **1.0.0 is a release candidate**, focused on Quick Focus. Window tracking now uses public Core Graphics metadata with the sandbox enabled. A separately signed sandbox probe enumerated external windows on a real Mac with both Accessibility and Screen Recording access denied. This is runtime evidence, not App Store approval. The signed App Store package has passed local structural checks; final compatibility testing, store assets and submission are still pending; no released download is available yet.

Local sandbox validation passed **18 tests**, including real AppKit overlay rendering, rounded corners, display-edge geometry and input pass-through checks. CI builds the sandbox configuration and tests both sandbox and Direct configurations.

Full-screen windows and dragging currently suspend dimming. Multiple physical displays, Mission Control, Stage Manager and screen sharing still need manual compatibility testing. The opening uses a 12-point corner radius; apps with custom window shapes may differ.

### Build and use

Requirements: **macOS 14 or later** and **Xcode with a compatible macOS SDK**. The project has no external package dependencies.

1. Clone this repository and open `DeepFocusMode.xcodeproj` in Xcode.
2. Select the **DeepFocusMode** scheme and **My Mac**. Choose your Apple Development signing identity in Signing & Capabilities.
3. Build and run. Open Settings from the menu bar icon.
4. Enable **Quick Focus** and adjust the intensity. No system permission setup is needed. Open the app again from Finder to reveal Settings when needed.

Only numeric window metadata and geometry are processed in memory. Mouse button/drag events trigger refreshes; a one-second reconciliation runs only while Quick Focus is enabled to catch keyboard-driven window changes. No keyboard content or screen images are captured. Dimming pauses during dragging and resumes on release.

With an Apple Development identity already installed, the local build helper discovers it without storing signing credentials in the repository:

```sh
bash Scripts/build-local.sh Release build
```

The resulting app is at `build/DerivedData/Build/Products/Release/DeepFocusMode.app`. This is a local development build, not a notarized release. The interface language follows macOS app language preferences; an in-app language selector is not implemented yet.

### Planned

After the initial Quick Focus release: focus sessions, optional completion notifications, a configurable global shortcut and a choice between global and per-display focus. These features are not implemented yet.

**Phase 2:** break timers, focus/break cycles, advanced profiles, application exclusions and launch at login.

### Privacy and license

No account, backend, tracking, analytics, ads or subscriptions. The app works offline and keeps settings locally. Read the [Privacy Policy](#privacy--gizlilik). Licensed under the [MIT License](LICENSE).

## Türkçe

Deep Focus Mode, etkin pencerenin çevresini karartarak dikkat dağıtan alanları azaltan, ücretsiz ve açık kaynaklı bir macOS menü çubuğu uygulamasıdır. SwiftUI ve AppKit ile geliştirilmiştir; tamamen çevrimdışı çalışır ve Türkçe ile İngilizce arayüz sunar.

### Şu anda kullanılabilenler

- **Hızlı Odak:** menü çubuğundan veya Ayarlar'dan karartmayı açıp kapatma.
- **Ayarlanabilir yoğunluk:** %0–85 arasında karartma seviyesi.
- **Pencere takibi:** herkese açık pencere bilgileri ve uygulama/fare olaylarıyla etkin pencerenin hareketini ve boyutunu izleme.
- **Yuvarlatılmış açıklık:** etkin pencere aydınlık kalır; karartma katmanları tıklamaları geçirir ve klavye odağını almaz.
- **Güvenli başlangıç:** her açılışta karartma kapalıdır. Güvenilir pencere konumu yoksa katmanlar kaldırılır. Erişilebilirlik veya Ekran Kaydı izni gerekmez.
- **Yerel tercihler:** yoğunluk kaydedilir; pencere başlıkları, ekran görüntüleri, yazılan içerikler ve kullanım geçmişi kaydedilmez.

### Durum ve sınırlamalar

**1.0.0 bir yayın adayıdır** ve Hızlı Odak özelliğine odaklanır. Pencere takibi artık sandbox açıkken herkese açık Core Graphics bilgilerini kullanır. Ayrı imzalanmış bir deneme uygulaması, gerçek Mac’te Erişilebilirlik ve Ekran Kaydı izinleri kapalıyken harici pencereleri listeledi. Bu çalışma kanıtıdır; App Store onayı değildir. Mağaza imzalı paket yerel yapı kontrollerinden geçti; son uyumluluk testleri, mağaza görselleri ve başvuru henüz tamamlanmadı; indirilebilir yayınlanmış bir sürüm yoktur.

Gerçek AppKit katmanlarının çizimi, yuvarlak köşeler, ekran kenarı geometrisi ve tıklamaları geçirme kontrolleri dahil **sandbox açıkken 18 yerel test geçti**. CI hem sandbox hem Direct yapılandırmalarının testlerini çalıştırır.

Tam ekran pencerelerde ve sürükleme sırasında karartma geçici olarak kaldırılır. Birden fazla fiziksel ekran, Mission Control, Stage Manager ve ekran paylaşımı için elle uyumluluk testleri henüz tamamlanmadı. Açıklık 12 punto köşe yarıçapı kullanır; özel pencere tasarımlarında köşeler farklı olabilir.

### Derleme ve kullanım

Gereksinimler: **macOS 14 veya üzeri** ve **uyumlu macOS SDK içeren Xcode**. Harici paket bağımlılığı yoktur.

1. Depoyu bilgisayarına al ve `DeepFocusMode.xcodeproj` dosyasını Xcode ile aç.
2. **DeepFocusMode** şemasını ve **My Mac** hedefini seç. Etkileşimli kullanım için Signing & Capabilities bölümünde Apple Development imza kimliğini ayarla.
3. Derleyip çalıştır. Menü çubuğundaki simgeden Ayarlar'ı aç.
4. **Hızlı Odak** seçeneğini açıp yoğunluğu ayarla. Sistem izni ayarlamak gerekmez. Ayarlar'ı tekrar göstermek için uygulamayı Finder'dan yeniden açabilirsin.

Yalnızca sayısal pencere bilgileri ve konumlar bellekte işlenir. Fare düğmesi/sürükleme olayları güncellemeleri tetikler; klavyeyle yapılan pencere değişiklikleri, yalnızca Hızlı Odak açıkken saniyede bir kontrol edilir. Klavye içeriği izlenmez ve ekran görüntüsü alınmaz. Sürükleme sırasında karartma duraklar, bırakınca devam eder.

Bilgisayarında Apple Development imza kimliği varsa yerel derleme yardımcısını kullanabilirsin. İmza bilgileri depoya kaydedilmez:

```sh
bash Scripts/build-local.sh Release build
```

Derlenen uygulama: `build/DerivedData/Build/Products/Release/DeepFocusMode.app`. Bu çıktı yerel geliştirme içindir; noter onaylı dağıtım sürümü değildir. Arayüz dili macOS uygulama dili tercihlerini izler; uygulama içi dil seçici henüz yoktur.

### Planlananlar

İlk Hızlı Odak sürümünden sonra odak oturumları, isteğe bağlı tamamlanma bildirimleri, ayarlanabilir genel klavye kısayolu ve tüm ekranlarda tek odak ya da ekran başına odak seçimi planlanıyor. Bunlar henüz uygulanmadı.

**Faz 2:** mola zamanlayıcıları, odak/mola döngüleri, gelişmiş profiller, uygulama istisnaları ve oturum açıldığında başlatma.

### Gizlilik ve lisans

Hesap, sunucu, takip, analiz, reklam ve abonelik yoktur. Uygulama çevrimdışı çalışır; ayarlar yerel olarak saklanır. [Gizlilik Politikası](#privacy--gizlilik). [MIT Lisansı](LICENSE) ile sunulur.

## Development / Geliştirme

Run the sandbox test suite / Sandbox testlerini çalıştır:

```sh
xcodebuild -project DeepFocusMode.xcodeproj -scheme DeepFocusMode \
  -configuration Debug -derivedDataPath build/SandboxTests -destination 'platform=macOS' \
  CODE_SIGN_STYLE=Automatic CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= \
  test
```

| Directory / Klasör | Contents / İçerik |
| --- | --- |
| `DeepFocusMode/App` | App lifecycle and model / Uygulama yaşam döngüsü ve model |
| `DeepFocusMode/Focus` | Window tracking, geometry and overlays / Pencere takibi, geometri ve karartma |
| `DeepFocusMode/UI` | Menu and Settings / Menü ve Ayarlar |
| `DeepFocusMode/Resources` | Localizations and app assets / Çeviriler ve uygulama görselleri |
| `DeepFocusModeTests` | Rendering, geometry and safety tests / Çizim, geometri ve güvenlik testleri |
| `Scripts` | Local signing and asset helpers / Yerel imzalama ve görsel yardımcıları |

Bug reports and contributions are welcome through [Issues](https://github.com/AlperCetinkaya/DeepFocusMode/issues) and pull requests. Include your macOS version, app version or commit, affected application and steps to reproduce. Avoid sharing private window content.

Hata bildirimlerini ve katkılarını [Issues](https://github.com/AlperCetinkaya/DeepFocusMode/issues) veya pull request üzerinden paylaşabilirsin. macOS sürümünü, uygulama sürümünü veya commit'i, etkilenen uygulamayı ve sorunu tekrarlama adımlarını ekle. Özel pencere içeriklerini paylaşma.

Create a local development-signed archive / Yerel geliştirme imzalı arşiv oluştur:

```sh
bash Scripts/build-local.sh Release archive
```

Archive / Arşiv: `build/Archives/DeepFocusMode.xcarchive`. App Store export requires distribution signing in Xcode Organizer / App Store aktarımı için Xcode Organizer’da dağıtım imzası gerekir.

Check the archive structure / Arşiv yapısını kontrol et:

```sh
python3 Scripts/check-archive.py
```

The checker reports distribution signing separately. With Store signing configured, use `Distribution/AppStoreExportOptions.plist` for a local export; it specifies `destination=export`, not an upload. / Kontrol aracı dağıtım imzasını ayrı raporlar. Mağaza imzaları ayarlandıktan sonra yerel aktarım için `Distribution/AppStoreExportOptions.plist` kullanılabilir; bu dosya yükleme yapmaz.

Store support and privacy links use this public GitHub README over HTTPS. The optional Pages site inherits a personal custom domain whose HTTPS configuration is separate. / Mağaza destek ve gizlilik bağlantıları bu herkese açık GitHub README’sini HTTPS üzerinden kullanır. İsteğe bağlı Pages sitesi, HTTPS yapılandırması ayrı olan kişisel alan adını devralır.

Support / Destek: [alper.cetinkaya.dev@gmail.com](mailto:alper.cetinkaya.dev@gmail.com).

## Support / Destek

For help, email [alper.cetinkaya.dev@gmail.com](mailto:alper.cetinkaya.dev@gmail.com) or open a [GitHub issue](https://github.com/AlperCetinkaya/DeepFocusMode/issues). Include your macOS version, app version and steps to reproduce. Do not share private screen content.

Destek için [alper.cetinkaya.dev@gmail.com](mailto:alper.cetinkaya.dev@gmail.com) adresine yazabilir veya [GitHub bildirimi](https://github.com/AlperCetinkaya/DeepFocusMode/issues) açabilirsiniz. macOS ve uygulama sürümünü, sorunu tekrarlama adımlarını ekleyin. Özel ekran içeriklerini paylaşmayın.

## Privacy / Gizlilik

### Privacy Policy — English

Deep Focus Mode — Privacy Policy
Updated: October 30, 2026

Deep Focus Mode operates entirely on your Mac. No account, backend, tracking, analytics, advertising or subscriptions are used.

Window tracking processes window identifiers, application process identifiers, window positions and sizes in memory to place dimming overlays. It does not read window titles, capture screen images or monitor typed content. Mouse button and drag events trigger geometry updates; their history is not saved. No Accessibility or Screen Recording permission is requested.

Dimming intensity and first-launch settings are stored locally in macOS preferences. They are not sent to us or any third party and remain until those preferences are removed. Dimming starts off each time the app launches. Disable Quick Focus or quit at any time to stop tracking and remove the overlays.

Support links open GitHub in your browser or your email app only when you choose them. GitHub and your email provider process information you choose to submit under their own privacy policies. Avoid posting private window content in public issues.

Contact: alper.cetinkaya.dev@gmail.com, or open an issue at github.com/AlperCetinkaya/DeepFocusMode. This policy describes the current app; future data handling changes will be reflected here.

### Gizlilik Politikası — Türkçe

Deep Focus Mode — Gizlilik Politikası
Güncelleme: 30 Ekim 2026

Deep Focus Mode tamamen Mac’inizde çalışır. Hesap, sunucu, takip, analiz, reklam veya abonelik kullanılmaz.

Pencere takibi; karartma katmanlarını yerleştirmek için pencere kimliklerini, uygulama işlem kimliklerini, pencere konumlarını ve boyutlarını bellekte işler. Pencere başlıkları okunmaz, ekran görüntüsü alınmaz ve yazılan içerik izlenmez. Fare düğmesi ve sürükleme olayları konum güncellemelerini tetikler; bunların geçmişi kaydedilmez. Erişilebilirlik veya Ekran Kaydı izni istenmez.

Karartma yoğunluğu ve ilk açılış ayarı macOS tercihlerinde yerel olarak saklanır. Bize veya üçüncü taraflara gönderilmez; tercihler kaldırılana kadar saklanır. Karartma her açılışta kapalı başlar. Takibi durdurmak ve katmanları kaldırmak için Hızlı Odak’ı kapatabilir veya uygulamadan çıkabilirsiniz.

Destek bağlantıları yalnızca seçtiğinizde tarayıcınızda GitHub’ı veya e-posta uygulamanızı açar. GitHub’a veya e-posta sağlayıcınıza gönderdiğiniz bilgiler kendi gizlilik politikalarına tabidir. Herkese açık hata bildirimlerinde özel pencere içeriklerini paylaşmayın.

İletişim: alper.cetinkaya.dev@gmail.com adresine yazabilir veya github.com/AlperCetinkaya/DeepFocusMode üzerinden hata bildirimi açabilirsiniz. Bu politika mevcut uygulamayı açıklar; veri işleme değişirse burada güncellenir.
