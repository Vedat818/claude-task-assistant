# Claude Task Assistant — Kullanım Kılavuzu

## Ne Yapar?

Belirlediğin saatte otomatik olarak:
1. Daha önce onayladığın görevleri uygular (git backup alarak)
2. Yeni görevlerin için öneriler üretir
3. Masaüstü bildirimi gönderir (başarı ve hata durumlarında ayrı ayrı)

---

## Günlük Kullanım

### 1. Aklına bir görev geldiğinde

İlgili projenin `tasks.md` dosyasını aç, altına yaz:

```
- [ ] Login butonunun rengini kırmızı yap
```

Kaydet. Bitti. Sistem bir sonraki çalışmada öneriler üretecek.

### 2. Bildirim geldiğinde

`tasks.md` dosyasını aç. Claude'un ürettiği öneriyi göreceksin:

```
- [ ] Login butonunun rengini kırmızı yap
  - Suggestion: Button.jsx'te bg-blue-500'u bg-red-500 ile değiştir
  - Approve: [ ]
```

**Beğendiysen:** `[ ]` yerine `[x]` yaz:
```
  - Approve: [x]
```

**Beğenmediysen ama yönlendirmek istiyorsan:** Önerinin altına `Answer:` satırı ekle:
```
  - Suggestion: CSS değişkenlerini değiştir...
  - Approve: [ ]
  - Answer: seçenek 2 istiyorum ama renkleri ben seçmek istiyorum
```
Sistem bir sonraki çalışmada cevabını okuyup yeni öneri üretir.

**Tamamen farklı bir şey istiyorsan:** Satırı silip görevi yeniden yaz, sistem bir sonraki çalışmada yeni öneri üretir.

**Görev belirsizse** Claude soru sorar:
```
- [ ] Performansı iyileştir
  - Question: Hangi sayfada, hangi metrik? (yükleme süresi mi, animasyon mu?)
  - Answer:
```

`Answer:` satırının sonuna cevabını yaz, bir sonraki çalışmada öneri gelir.

### 3. Bir sonraki çalışmada

Onayladıkların uygulanmış olur, `tasks.md`'de `[x]` ile kapanmış görürsün.

---

## tasks.md Formatı

Her projenin kökünde bir `tasks.md` olmalı:

```markdown
---
model: sonnet
---

# Tasks

- [ ] Yapılacak görev
- [x] Tamamlanmış görev
```

### Model Seçimi

Dosyanın başındaki `model:` satırını değiştirerek proje bazında model seçebilirsin:

| Değer | Model | Ne zaman? |
|---|---|---|
| `haiku` | Claude Haiku | Basit değişiklikler (renk, metin, küçük düzeltme) |
| `sonnet` | Claude Sonnet | Çoğu görev — varsayılan |
| `opus` | Claude Opus | Mimari değişiklik, karmaşık refactor |

---

## Geri Alma

Claude bir şeyi yanlış yaptıysa:

```bash
cd ~/Projeler/PROJE_ADI
git log --oneline   # commit geçmişini gör
git revert HEAD     # son değişikliği geri al
```

Her görev öncesi otomatik backup commit atılır, bu yüzden her zaman geri dönebilirsin.

---

## Manuel Çalıştırma

Cron'u beklemeden çalıştırmak istersen:

```bash
bash ~/claude-task-assistant/scripts/run.sh
```

Daha spesifik komutlar:

```bash
# Sadece öneri üret
bash ~/claude-task-assistant/scripts/check-tasks.sh

# Sadece onaylananları uygula
bash ~/claude-task-assistant/scripts/apply-tasks.sh
```

### Kuru Çalıştırma (Dry Run)

Gerçekte değişiklik yapmadan ne yapılacağını görmek istersen:

```bash
# Tüm sistemi dry run ile çalıştır
bash ~/claude-task-assistant/scripts/run.sh --dry-run

# Sadece öneri üretimini test et
bash ~/claude-task-assistant/scripts/check-tasks.sh --dry-run

# Sadece uygulamayı test et
bash ~/claude-task-assistant/scripts/apply-tasks.sh --dry-run
```

Dry run modunda hiçbir dosya değiştirilmez, sadece hangi projelerde ne yapılacağı terminale ve loglara yazılır.

---

## Loglar

Her çalışmanın kaydı burada:
```
~/claude-task-assistant/logs/
```

Bir şeyler ters gittiyse log dosyasına bak. 30 günden eski loglar otomatik olarak silinir.

---

## Otomatik CLAUDE.md Olusturma

Sistem bir projeyi ilk kez islerken, projede `CLAUDE.md` dosyasi yoksa otomatik olarak olusturur. Bu dosya:
- Projenin ne yaptigi (1-2 cumle)
- Kullanilan teknolojiler ve framework'ler
- Dosya yapisi ozeti
- Onemli konvansiyonlar

Claude sonraki calismalarda bu dosyayi okuyarak projeyi daha iyi anlar ve daha isabetli oneriler uretir. Bu dosyayi silmemeniz onerilir.

---

## Güvenlik Özellikleri

- **Lock file:** Aynı anda birden fazla `run.sh` çalışmasını engeller. Eğer önceki süreç çökmüşse lock otomatik temizlenir.
- **Git backup:** Her görev uygulanmadan önce otomatik backup commit atılır.
- **Hata bildirimi:** Claude komutu başarısız olursa masaüstü bildirimi ile uyarılırsın.
- **Log rotasyonu:** 30 günden eski loglar otomatik silinir.

---

## Sistemi Kapatma / Durdurma / Sıfırlama

### Geçici Durdur (cron'u kapat)

```bash
crontab -e
# Satırın başına # koy:
# #0 6 * * * /bin/bash ~/claude-task-assistant/scripts/run.sh
# Kaydet: ESC sonra :wq
```

Tekrar açmak için `#`'i sil.

### Tamamen Kaldır (cron + sistem dosyaları)

```bash
# Cron'dan kaldır
crontab -l | grep -v "claude-task-assistant" | crontab -

# Sistem dosyalarını sil
rm -rf ~/claude-task-assistant

# Projelerdeki tasks.md'leri de silmek istersen (isteğe bağlı):
rm ~/Projeler/proje-adi/tasks.md
```

Projelerin kodu ve git geçmişi **etkilenmez**, sadece sistem dosyaları gider.

---

## Cron Saatini Değiştirme

```bash
crontab -e
```

`0 6 * * *` kısmındaki `6`'yı istediğin saate çevir. Örnek: `0 8` → sabah 08:00.

---

## Sifirdan Yeni Proje Olusturmak

`new-projects.md` dosyasina fikir yaz:

```
- [ ] proje-adi: Projenin kisa aciklamasi
```

Sistem otomatik olarak:
1. Claude oneri uretir (teknoloji, yapi, ozellikler)
2. Onaylarsan (`Approve: [x]`) projeyi `~/Projeler/proje-adi` altinda olusturur
3. `tasks.md` dosyasini koyar, `config.sh`'e ekler, git init yapar

Artik proje normal akisa dahil olur ve `tasks.md`'sine gorev yazabilirsin.

---

## PROJECTS ve PROJECTS_DIR Farkı

- **`PROJECTS`** — halihazırda sahip olduğun projelerin listesi. Bilgisayarında nerede olursa olsun eklenebilir. Sistem her birinin içindeki `tasks.md`'yi tarar.
- **`PROJECTS_DIR`** — sadece `new-projects.md` tarafından kullanılır. Bir proje fikrini onayladığında yeni proje buraya oluşturulur ve otomatik olarak `PROJECTS` listesine eklenir — elle bir şey yapman gerekmez.

## Mevcut Projeyi Sisteme Eklemek

1. Projenin klasörüne `tasks.md` ekle
2. `config.sh` dosyasını aç, `PROJECTS` listesine projenin yolunu ekle:

```bash
PROJECTS=(
  "$HOME/work/mevcut-proje"
  "$HOME/Desktop/baska-proje"
  "$HOME/herhangi/bir/yol"   # <-- buraya ekle
)
```

---

## Dosya Yapısı

```
~/claude-task-assistant/
  config.sh              — proje listesi ve ayarlar
  scripts/run.sh         — cron'un çalıştırdığı ana script (lock + log rotasyonu)
  scripts/check-tasks.sh — öneri üretme
  scripts/apply-tasks.sh — onaylananları uygulama
  new-projects.md               — sifirdan proje fikirleri
  kullanim-kilavuzu.md   — bu dosya
  logs/                  — çalışma kayıtları (30 gün tutulur)

~/Projeler/
  proje-adi/tasks.md
  baska-proje/tasks.md
```
