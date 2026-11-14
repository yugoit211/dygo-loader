# DYGO Loader — Client Edition (hanya-baca)

Loader untuk **menjalankan** file PHP yang sudah di-encode oleh DYGO (gaya ionCube
Loader). Edisi ini **hanya bisa membaca/menjalankan** — **tidak bisa** membuat
enkripsi (tidak ada encoder, `keygen`, maupun `encode`). Master key **tidak**
ada di repo ini; Anda memasukkannya sendiri (dari vendor) setelah install.

## Instalasi satu baris

**Linux / macOS**
```bash
curl -fsSL https://raw.githubusercontent.com/yugoit211/dygo-loader/main/install.sh | bash
```

**Windows (PowerShell)**
```powershell
irm https://raw.githubusercontent.com/yugoit211/dygo-loader/main/install.ps1 | iex
```

Installer akan:
1. mendeteksi PHP (versi, ABI, OS/arch),
2. memasang biner loader (prebuilt bila ada, atau build dari sumber bila ada `phpize`),
3. mengaktifkannya di `php.ini`,
4. memasang perintah `dygo`,
5. menyiapkan lokasi master key.

Prasyarat: **PHP 8.1+**. Build dari sumber butuh paket `php-dev` (`phpize`).

## Memasukkan master key (dari vendor)

Loader butuh master key untuk mendekripsi. Minta key (64 hex) ke vendor Anda,
lalu salah satu cara berikut:

```bash
# cara 1 — file (paling andal, termasuk untuk web/php-fpm)
echo 'KEY_HEX_DARI_VENDOR' > ~/.dygo-client/dygo.key
chmod 600 ~/.dygo-client/dygo.key

# cara 2 — environment variable
export DYGO_KEY=KEY_HEX_DARI_VENDOR
```

Loader mencari key berurutan: `DYGO_KEY` → `DYGO_MASTER_KEY` → `DYGO_KEY_FILE`
→ `~/.dygo-client/dygo.key` → `/etc/dygo/dygo.key`.

> Untuk web (Apache/Nginx + php-fpm): simpan key sebagai **file** di atas (env
> sering tak terbaca oleh php-fpm), lalu **restart** php-fpm.

## Verifikasi master key

Installer hanya mengecek **format** key (64 hex), bukan kebenarannya. Untuk
memastikan key benar-benar cocok, uji dengan file ter-encode dari vendor:

```bash
dygo verify /path/ke/file-dari-vendor.php
# ✓ Master key COCOK …   atau   ✗ Master key TIDAK cocok
```

Vendor dapat mengirim **file canary** (`dygo canary`). Taruh di
`~/.dygo-client/canary.php` → installer **otomatis memverifikasi** key saat
install (dan minta ketik ulang bila salah). Atau jalankan installer dengan
`DYGO_VERIFY_FILE=/path/canary.php`.

## Perintah

```bash
dygo doctor       # cek: loader aktif? key terpasang?
dygo verify <f>   # uji master key cocok dengan file ter-encode
dygo setkey       # pasang/ubah master key (interaktif)
dygo machineid    # node-hash server ini → kirim ke vendor untuk node-lock
dygo uninstall    # lepas loader
```

`dygo keygen` dan `dygo encode` **sengaja tidak tersedia** di edisi klien.

## Setelah terpasang

File ter-encode dari vendor **jalan otomatis** — tanpa file pendukung, tanpa
`include` tambahan. Jalankan seperti PHP biasa:

```bash
php index.php          # bila index.php ter-encode, loader mendekripsi di memori
```

## Keamanan

- Repo ini **tidak** memuat master key. Biner loader di sini **keyless**; key
  disuplai saat runtime (env/file), jadi aman untuk repo publik.
- Jaga file `~/.dygo-client/dygo.key`. Siapa pun yang punya key bisa mendekripsi.
- Ini menaikkan biaya reverse-engineering secara signifikan, bukan jaminan mutlak
  (sama seperti ionCube).

## Tanpa loader C (fallback)

Bila server tak punya `phpize`/prebuilt, pakai loader PHP-murni: sertakan
`~/.dygo-client/runtime/dygo-runtime.php` + `shared/dygo-codec.php` dan set
master key. Proteksinya lebih lemah (key berdampingan dengan kode).
