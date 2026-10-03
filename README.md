# Medion Signium 14 S1 — dahili klavye ve Fn tuşları

Bu sürücü, bu bilgisayarda çalışan özel serio klavye çözümüne ses, medya, uyku ve touchpad tuşlarını ekler. Normal F1–F12 ile mevcut AltGr düzeltmesi korunur. MEDION 14 S1 OLED üzerinde Fn+F1'in `0x76` kodu gönderdiği fiziksel denemeyle ölçüldü; `medion_kbd.conf` bu kodu touchpad açma/kapatmaya eşler.

## Derleme ve kod kontrolü

Aşağıdaki komutları repo dizininde çalıştırın.

```bash
make
python3 ./tests/test_scancodes.py
```

Test, sürücünün gerçek kod çözme fonksiyonlarını çalıştırır. Donanımın gönderdiği kodları ve KDE'nin tepkisini doğrulamak için ayrıca fiziksel tuş denemesi gerekir.

## Kurulum

```bash
sudo bash ./install.sh
```

Mevcut çekirdeğin başlıkları, DKMS ve LLVM derleme araçları gereklidir. Kurulum, çalışan modül ve betikleri `/var/lib/medion-signium-keyboard/backups/` altında yedekler. Eski 1.0 DKMS kaydı korunur. Yeni 1.1 modülü DKMS ile derlenir, yüklenir ve serio0 bağlantısı kontrol edilir. Modül yenilenirken klavye kısa süre yeniden bağlanır. Yükleme başarısız olursa eski sürücüye dönülür.

`--no-activate` seçeneği kurulumu yapıp yüklemeyi yeniden başlatmaya bırakır. Çalışan sistemin mevcut `i8042.nopnp=1 i8042.direct=1` önyükleme ayarları bu güncellemede değiştirilmez.

## Fiziksel teşhis

```bash
sudo python3 ./watch_hotkeys.py --seconds 90
```

Bu araç klavyeyi kilitlemez. F tuşları, medya/uyku/touchpad olayları ve eşlenmemiş kodları gösterir; normal yazı girişini kaydetmez. Önce Fn+F4/F5/F6 ve Fn+F10/F11/F12, sonra Fn+F1 denenmelidir. Fn+F2 uyku denemesi en son yapılır; bilgisayarı güç düğmesine kısa basarak uyandırmak gerekebilir.

F10/F12 için standart PS/2 önceki/sonraki parça kodları desteklenir. Oynatıcıların bu tuşlara verdiği tepki değişebilir. Zaman içinde geri/ileri sarma isteniyorsa önce tuşun gönderdiği kod ve istenen oynatıcı davranışı doğrulanmalıdır.

Bu bilgisayarda ölçülen touchpad ayarı `/etc/modprobe.d/medion_kbd.conf` dosyasında `options medion_kbd touchpad_scancode=0x76` satırıdır. Kurulum, dosya henüz yoksa repodaki bu ayarı kurar; mevcut ayarı korur. Çalışan modüle yeniden yüklemeden uygulamak için:

```bash
sudo bash ./set_touchpad_code.sh 0x76
```

Başka bir modelde farklı kod ölçülürse `touchpad_scancode` değiştirilebilir; E0 öneki `0xe000` olarak kodlanır. Modülün kendi varsayılanı 0 olup eşleme kurulum ayarıyla etkinleşir.

İsteğe bağlı `debug_unknown=1` parametresi eşlenmemiş kodları çekirdek günlüğüne yazar; normal kullanımda kapalıdır.

## Geri dönüş

```bash
sudo bash ./rollback.sh
```

En son sistem yedeği seçilir. Belirli bir yedek dizini ilk argüman olarak verilebilir. Yedek, kullanılan çekirdeğe ait olmalıdır.

Kurulumun sistem yedekleri `/var/lib/medion-signium-keyboard/backups/` altında tutulur.

## Kaynak ve lisans

Bu proje [mrelmida/medion-signium-keyboard](https://github.com/mrelmida/medion-signium-keyboard) projesinden türetilmiştir. Özgün Git geçmişi ve modül yazar bilgisi korunur. Lisans: GPL v2.
