# Dokumentasi Teknis & Panduan Penggunaan: PDT Tracker

Dokumen ini berisi penjelasan menyeluruh mengenai cara kerja aplikasi **PDT Tracker**, prosedur melacak dan membunyikan alarm pada perangkat yang hilang, panduan penggunaan antarmuka, tata cara *deployment* hingga *production*, serta arsitektur koneksi jaringan.

---

## 📑 Daftar Isi
1. [Cara Kerja Aplikasi (Arsitektur Sistem)](#1-cara-kerja-aplikasi-arsitektur-sistem)
2. [Skenario Penanganan & Pelacakan Perangkat Hilang](#2-skenario-penanganan--pelacakan-perangkat-hilang)
3. [Panduan Penggunaan Aplikasi](#3-panduan-penggunaan-aplikasi)
4. [Persyaratan & Arsitektur Jaringan (LAN, Hotspot, vs Internet)](#4-persyaratan--arsitektur-jaringan-lan-hotspot-vs-internet)
5. [Panduan Deployment & Production](#5-panduan-deployment--production)

---

## 1. Cara Kerja Aplikasi (Arsitektur Sistem)

Aplikasi **PDT Tracker** dirancang untuk menerima sinyal jarak jauh (*remote signal*) via protokol **MQTT** (*Message Queuing Telemetry Transport*) dan merespons dengan memicu alarm suara berfrekuensi tinggi serta memaksimalkan volume perangkat secara otomatis.

```
┌──────────────────────────┐          ┌──────────────────────┐          ┌───────────────────────────┐
│     Pemicu / Admin       │          │     MQTT Broker      │          │   Perangkat PDT Tracker   │
│  (Web/Dashboard/Mobile)  │ ───────> │ (Mosquitto/EMQX/Cloud│ ───────> │      (HP Android)         │
│  Publish: "TRIGGER"      │          │       Broker)        │          │  Subscribed: Topic Alert  │
└──────────────────────────┘          └──────────────────────┘          └─────────────┬─────────────┘
                                                                                      │
                                                                       ┌──────────────┴──────────────┐
                                                                       │  1. Force Volume Max (100%) │
                                                                       │  2. Play alarm.mp3 Loop     │
                                                                       └─────────────────────────────┘
```

### Komponen Utama Logika:
1. **`MqttService` (`lib/services/mqtt_service.dart`)**:
   * Menghubungkan HP ke MQTT Broker (`server`, `port`).
   * Melakukan *Subscribe* ke topik tertentu (contoh: `pdt_tracker/alerts`).
   * Menerima pesan (*payload*) secara *real-time* dari broker.

2. **`AlarmService` (`lib/services/alarm_service.dart`)**:
   * Menggunakan `perfect_volume_control` untuk memaksimalkan volume suara sistem HP ke tingkat tertinggi ($100\%$).
   * Menggunakan `audioplayers` untuk memutar fail audio berfrekuensi tinggi (`assets/audio/alarm.mp3`) secara berulang (*looping*).

3. **`TestingInterface` (`lib/main.dart`)**:
   * Antarmuka pengujian visual untuk memantau status alarm, status koneksi MQTT, serta membaca riwayat *log* aktivitas sistem.

---

## 2. Skenario Penanganan & Pelacakan Perangkat Hilang

### Bagaimana Cara Membunyikan Alarm dari Jarak Jauh Jika Perangkat Hilang?

Jika HP yang terpasang aplikasi PDT Tracker hilang atau terselip:

1. **Jalankan Perintah Pemicu dari Mana Saja**:
   Admin/Pemilik cukup mengirimkan pesan MQTT dengan *payload* `TRIGGER` atau `EMERGENCY_ALARM` ke topik yang terdaftar (contoh: `pdt_tracker/alerts`).
   *Dapat dikirim dari HP lain, laptop, Dashboard Web, atau CLI MQTT Client (seperti MQTTX atau HiveMQ Web Client).*

2. **Reaksi Otomatis Perangkat**:
   * Begitu *payload* diterima oleh HP, aplikasi langsung **memaksimalkan volume media HP ke tingkat paling keras ($100\%$)**, meskipun HP sebelumnya di-set mode getar/silent.
   * Audio alarm `alarm.mp3` akan langsung meraung secara terus-menerus (*looping*) hingga ada perintah berhenti (`stopAlarm`) dikirimkan atau dimatikan via aplikasi.

3. **Rencana Pengembangan Fitur Pelacakan Lokasi (Tracking)**:
   Untuk melacak posisi koordinat HP yang hilang, aplikasi dapat ditingkatkan dengan menambahkan *geolocation listener*:
   * Saat menerima perintah `GET_LOCATION`, aplikasi membaca koordinat GPS perangkat.
   * Aplikasi mempublikasikan balik pesan balasan ke topik `pdt_tracker/location` berupa koordinat latitude & longitude:
     ```json
     {
       "device_id": "RRCX809G8CM",
       "latitude": -6.175392,
       "longitude": 106.827153,
       "battery": 85
     }
     ```

---

## 3. Panduan Penggunaan Aplikasi

### Langkah Penggunaan Prototipe:
1. **Buka Aplikasi**: Layar akan menampilkan *Dashboard Status* (Alarm Status: `IDLE`, MQTT Status: `DISCONNECTED`).
2. **Koneksi ke Broker MQTT**:
   * Masukkan alamat host MQTT Server (default: `test.mosquitto.org`).
   * Masukkan nama Topik (default: `pdt_tracker/alerts`).
   * Tekan tombol **`CONNECT MQTT`**.
3. **Pengujian Alarm Manual**:
   * Tekan tombol **`PLAY ALARM`** untuk menguji suara alarm dan pemaksaan volume maksimum.
   * Tekan tombol **`STOP ALARM`** untuk menghentikan alarm.
4. **Pengujian Pemicu Jarak Jauh (Remote Trigger)**:
   * Tekan tombol kirim pesan (**Send Icon**) dengan *payload* `EMERGENCY_ALARM`.
   * Perhatikan *log* aktivitas akan mencatat pesan masuk dan alarm akan otomatis berbunyi.

---

## 4. Persyaratan & Arsitektur Jaringan (LAN, Hotspot, vs Internet)

### Apakah Harus Satu Jaringan LAN / Wi-Fi Hotspot?

**Jawabannya: TIDAK HARUS SATU JARINGAN.** Koneksi tergantung pada jenis Broker MQTT yang Anda gunakan.

| Jenis Arsitektur Jaringan | Cara Kerja & Alamat Host | Kelebihan & Kekurangan | Cocok Untuk |
| :--- | :--- | :--- | :--- |
| **Local LAN / Wi-Fi Hotspot** | HP dan Pemicu berada di Wi-Fi/Hotspot yang sama. Host berupa IP lokal (contoh: `192.168.1.50`). | ➕ Tidak butuh internet luar.<br>➖ Hanya bekerja dalam jangkauan sinyal Wi-Fi lokal. | Pengujian internal laboratorium / area pabrik terbatas. |
| **Internet / Cloud MQTT Broker** *(Rekomendasi Production)* | Broker berada di Server Cloud (contoh: AWS, DigitalOcean, HiveMQ, EMQX Cloud, atau `test.mosquitto.org`). | ➕ **HP dapat berada di mana saja di seluruh dunia** (selama ada koneksi paket data seluler/Wi-Fi).<br>➕ Melacak/membunyikan alarm bisa dilakukan dari jarak jauh tanpa batas area. | **Penggunaan Production / Pelacakan Perangkat Hilang**. |

> 💡 **Kesimpulan Jaringan:**  
> Untuk skenario **pencarian HP hilang**, gunakan **Cloud MQTT Broker (Internet)**. Dengan begitu, HP yang terpasang aplikasi dapat menerima sinyal alarm kapan saja dan di mana saja selama HP terhubung ke paket data internet.

---

## 5. Panduan Deployment & Production

### A. Persiapan Kode untuk Mode Release / Production
1. **Keamanan MQTT (SSL/TLS & Otentikasi)**:
   Pada lingkungan produksi, ubah koneksi MQTT untuk menggunakan port aman (**8883** dengan TLS/SSL) serta tambahkan *Username* dan *Password*:
   ```dart
   _client = MqttServerClient.withPort('mqtt.perusahaan.com', clientId, 8883);
   _client!.secure = true;
   _client!.securityContext = SecurityContext.defaultContext;
   ```

2. **Izin Latar Belakang (Background Service)**:
   Agar aplikasi tetap dapat menerima pesan MQTT saat layar HP mati atau aplikasi ditutup, tambahkan dukungan *Foreground Service* & *Wakelock* pada Android Manifest:
   * `android/app/src/main/AndroidManifest.xml`:
     ```xml
     <uses-permission android:name="android.permission.INTERNET" />
     <uses-permission android:name="android.permission.WAKE_LOCK" />
     <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
     ```

### B. Langkah Build Berkas Release (APK / App Bundle)
Jalankan perintah berikut pada terminal di folder proyek:

1. **Build APK Release (Untuk Diinstal Langsung)**:
   ```bash
   flutter build apk --release
   ```
   *Hasil berkas APK berada di:* `build/app/outputs/flutter-apk/app-release.apk`

2. **Build App Bundle (Untuk Google Play Store)**:
   ```bash
   flutter build appbundle --release
   ```
   *Hasil berkas AAB berada di:* `build/app/outputs/bundle/release/app-release.aab`

---

*Dokumen ini dibuat secara otomatis sebagai acuan teknis pengembangan dan implementasi produksi aplikasi PDT Tracker.*
