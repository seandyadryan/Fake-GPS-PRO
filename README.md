# Fake GPS PRO

Aplikasi Flutter untuk memilih lokasi pada peta dan menjalankan mock location di Android.
SDK proyek: Flutter 3.41.2 / Dart 3.11 (lihat `.fvmrc`). Backend mock location hanya di Android;
iOS belum memiliki implementasi spoof.

## Penggunaan

1. Aktifkan **Developer Mode**: Pengaturan → Tentang ponsel → ketuk Build number / Nomor bentukan 7 kali.
2. Buka **Developer Options → Select mock location app → Fake GPS PRO**.
3. Aktifkan lokasi perangkat dan izinkan akses lokasi saat aplikasi digunakan.
4. Pilih titik pada peta, cari alamat, buka lokasi tersimpan, atau masukkan koordinat.
5. Tekan **Mulai spoof**. Status aktif baru ditampilkan setelah layanan Android berhasil memasang provider dan mengirim lokasi pertama.
6. Untuk mengganti lokasi saat aktif, pilih titik baru lalu tekan **Perbarui spoof**. Marker hijau menunjukkan lokasi aktif; pin menunjukkan titik pilihan.
7. Tekan **Stop mock location** di aplikasi atau notifikasi untuk menghentikan pembaruan, membatalkan rute, dan melepas provider uji. Lokasi asli dapat memerlukan waktu untuk diperbarui GPS.

Panduan di aplikasi menampilkan status Developer Mode, pilihan aplikasi mock, layanan lokasi,
dan izin lokasi. Status diperiksa kembali saat aplikasi dibuka dan secara berkala selama proses aplikasi hidup.
Notifikasi memerlukan izin pada Android 13+, tetapi menolak izin notifikasi tidak menghalangi tombol stop di aplikasi.
Stop tidak menonaktifkan Developer Mode atau mengubah pilihan aplikasi mock di pengaturan Android.

## Fitur

- Peta OpenStreetMap, pencarian alamat Nominatim, input koordinat, zoom, dan lokasi perangkat.
- Simpan/hapus lokasi favorit dan riwayat 50 lokasi spoof terakhir, termasuk saat offline.
- Rute berupa perpindahan antartitik setiap 3 detik (bukan navigasi atau interpolasi kecepatan).
  Tambahkan minimal dua titik dan mulai spoof dahulu. **Stop rute** menghentikan perpindahan;
  **Stop mock location** menghentikan seluruh spoof. Titik rute tetap tersimpan selama sesi aplikasi.
- UI terang/gelap, layout portrait/landscape, panel yang dapat digulir pada layar kecil.
- Validasi koordinat hingga lapisan Android, laporan kegagalan native, dan proteksi klik mulai berulang.

Peta dan pencarian membutuhkan internet. Riwayat memakai koordinat sehingga tidak menunda spoof
untuk menunggu geocoding. Simulasi rute memakai timer Flutter: jalankan dengan aplikasi terbuka;
kelanjutan timer ketika aplikasi ditangguhkan Android belum dijamin. Layanan lokasi statis berjalan
sebagai foreground service dan tidak otomatis mengaktifkan ulang spoof setelah proses dimatikan.

## Bahasa

Tekan ikon globe di halaman utama untuk mencari dan memilih bahasa. Tersedia
80 pilihan bahasa/varian, termasuk Indonesia, Inggris, Arab, dan Mandarin sederhana
serta tradisional. Daftar lengkap ada di `lib/l10n/languages.json`. Pilihan disimpan
dan berlaku untuk halaman aplikasi, pesan kesalahan, panduan, serta notifikasi Android.
Mengganti bahasa tidak menghentikan sesi spoof yang sedang aktif.

Pilihan **Ikuti bahasa perangkat** memakai bahasa perangkat yang didukung, dengan
fallback Inggris. Varian regional memakai terjemahan bahasa induk; Norwegia Nynorsk
memakai Bokmål dan Swiss German memakai Jerman. Ini belum mencakup setiap bahasa
di dunia. Bahasa kanan-ke-kiri didukung, sedangkan input koordinat tetap kiri-ke-kanan.
Input menerima angka Arab/Persia dan beberapa aksara Asia Selatan serta pemisah
desimal titik/koma. Tanggal riwayat mengikuti format bahasa antarmuka.

Terjemahan antarmuka tersimpan di aplikasi dan bekerja offline. Nama tempat hasil
pencarian mengikuti ketersediaan data penyedia; tulisan pada tile peta tidak berubah.
Terjemahan saat ini merupakan draf berbantuan mesin/AI dan perlu ditinjau penutur asli
sebelum rilis komersial. Kontrol kalender Cupertino Pashto yang tidak digunakan aplikasi
masih memakai fallback Inggris. Backend spoof tetap khusus Android.

Untuk memperbarui katalog, edit `lib/l10n/app_*.arb`, lalu jalankan:

```powershell
python tool/sync_l10n.py
flutter gen-l10n
dart format lib/l10n/languages.dart
```

`sync_l10n.py` memvalidasi kelengkapan pesan/placeholder dan menyinkronkan label
notifikasi native. `generate_draft_translations.py` merupakan alat pengembangan opsional
yang mengirim teks UI umum ke layanan terjemahan publik Google; tidak dijalankan aplikasi
dan hasilnya tetap perlu diperiksa manusia.

## Verifikasi pengembangan

Dengan Flutter 3.41.2 di PATH (atau gunakan `fvm flutter`):

```powershell
flutter analyze
flutter test --timeout 60s
flutter build apk --debug
```

APK debug: `build/app/outputs/flutter-apk/app-debug.apk`.
Pratinjau UI opsional: `flutter test test/widget_test.dart --dart-define=CAPTURE_UI=true --timeout 60s`.
Atur `FLUTTER_ROOT` ke direktori SDK bila belum tersedia. Gambar disimpan di `build/ui-preview`.
Tile peta diganti placeholder dalam pengujian agar tidak memanggil jaringan.

Tes mencakup prasyarat spoof, kegagalan native, validasi koordinat, konfirmasi mulai,
stop/mock/rute, sinkronisasi stop dari notifikasi, input yang tidak tertimpa polling,
perubahan lokasi tersimpan pada panel terbuka, dan layout berbagai ukuran layar.
Tes lokalisasi memeriksa katalog 80 bahasa, arah tulisan, layout layar kecil,
format tanggal, input angka lokal, penyimpanan pilihan bahasa, dan perpindahan
bahasa tanpa membuat ulang provider lokasi.
Method channel Android dimock dalam tes Flutter; build APK memeriksa kompilasi native,
bukan keberhasilan injeksi GPS pada perangkat fisik.

## Checklist pengujian di Android

- Developer Mode mati: mulai harus ditolak dan panduan terbuka.
- Developer Mode aktif tetapi aplikasi mock belum dipilih: mulai harus ditolak.
- Izin lokasi ditolak/diblokir atau GPS mati: tampilkan petunjuk yang sesuai.
- Pengaturan lengkap: spoof koordinat, periksa lokasi aktif, lalu perbarui koordinat.
- Stop dari aplikasi dan notifikasi: pastikan notifikasi hilang, status tidak aktif, dan GPS mendapatkan lokasi asli kembali.
- Buka ulang UI saat service aktif: status serta koordinat aktif harus tersinkron.
- Jalankan rute minimal dua titik; stop rute tidak boleh menambah titik atau melanjutkan timer.
- Cabut pilihan aplikasi mock saat service aktif: service harus berhenti dan kegagalannya terlihat.
- Coba pencarian online/offline, simpan/hapus lokasi, dan pilih kembali dari riwayat.

Referensi implementasi Android:
[LocationManager](https://developer.android.com/reference/android/location/LocationManager),
[prasyarat foreground service lokasi](https://developer.android.com/develop/background-work/services/fgs/service-types#location).
