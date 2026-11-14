#!/usr/bin/env sh
# =============================================================================
#  DYGO Loader — pemasang CLIENT EDITION (hanya-baca)
#  Pakai:  curl -fsSL https://raw.githubusercontent.com/yugoit211/dygo-loader/main/install.sh | bash
# -----------------------------------------------------------------------------
#  Memasang LOADER yang HANYA bisa MENJALANKAN file PHP ter-encode dari vendor.
#  TIDAK bisa membuat enkripsi (tanpa encoder / keygen). Master key TIDAK ada
#  di repo ini — Anda memasukkannya sendiri (dari vendor) setelah install.
# =============================================================================
set -eu

REPO="${DYGO_REPO:-yugoit211/dygo-loader}"
BRANCH="${DYGO_BRANCH:-main}"
HOMEDIR="${HOME:-/root}"
DYGO_DIR="${DYGO_DIR:-$HOMEDIR/.dygo-client}"
BIN_DIR="${DYGO_BIN_DIR:-$HOMEDIR/.local/bin}"

c_grn='\033[32m'; c_red='\033[31m'; c_ylw='\033[33m'; c_cyn='\033[36m'; c_rst='\033[0m'; c_b='\033[1m'
say()  { printf "%b\n" "$1"; }
ok()   { printf "${c_grn}✓${c_rst} %s\n" "$1"; }
inf()  { printf "${c_cyn}ℹ${c_rst} %s\n" "$1"; }
wrn()  { printf "${c_ylw}•${c_rst} %s\n" "$1"; }
die()  { printf "${c_red}✗ %s${c_rst}\n" "$1" >&2; exit 1; }

say "${c_b}${c_cyn}DYGO Loader${c_rst} — pemasang client (hanya-baca)\n"

# -- 1) prasyarat --------------------------------------------------------------
PHP="${PHP:-php}"
command -v "$PHP" >/dev/null 2>&1 || die "PHP tidak ditemukan. Pasang PHP 8.1+ lalu ulangi."
PHPVER="$("$PHP" -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')"
ABI="$("$PHP" -r 'echo preg_replace("/\\D/","",(string)ini_get("extension_dir"));')"
EXTDIR="${DYGO_EXTDIR:-$("$PHP" -r 'echo (string)ini_get("extension_dir");')}"
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"      # linux / darwin
ARCH="$(uname -m)"                                  # x86_64 / arm64 / aarch64
case "$ARCH" in aarch64) ARCH=aarch64;; arm64) ARCH=arm64;; x86_64|amd64) ARCH=x86_64;; esac
PLAT="${OS}-${ARCH}"
ok "PHP $PHPVER ($OS/$ARCH), ABI $ABI, extension_dir: $EXTDIR"

# -- 1b) minta master key DI AWAL (interaktif, jalan juga lewat curl|bash) ------
is_hex64() { printf '%s' "$1" | grep -Eqi '^[0-9a-f]{64}$'; }
KEY_INPUT="${DYGO_KEY:-}"
if [ -z "$KEY_INPUT" ] && { [ -r /dev/tty ] && [ -w /dev/tty ]; } 2>/dev/null; then
  say ""
  printf "%b" "${c_b}Master key dari vendor (64 hex)${c_rst} — tempel lalu Enter:\n> " > /dev/tty 2>/dev/null
  IFS= read -r _k < /dev/tty 2>/dev/null || _k=""
  _k="$(printf '%s' "$_k" | tr -d ' \t\r\n')"
  if [ -n "$_k" ]; then
    if is_hex64 "$_k"; then KEY_INPUT="$_k"
    else wrn "Key bukan 64 hex — akan diminta lagi saat verifikasi."; fi
  fi
fi

# -- 2) ambil sumber (tarball repo) atau pakai lokal ---------------------------
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
if [ -n "${DYGO_LOCAL_SRC:-}" ]; then
  SRC="$DYGO_LOCAL_SRC"
  inf "Memakai sumber lokal: $SRC"
else
  inf "Mengunduh dygo-loader ($REPO@$BRANCH) ..."
  URL="https://codeload.github.com/$REPO/tar.gz/refs/heads/$BRANCH"
  if command -v curl >/dev/null 2>&1; then curl -fsSL "$URL" -o "$TMP/src.tgz"
  elif command -v wget >/dev/null 2>&1; then wget -qO "$TMP/src.tgz" "$URL"
  else die "butuh curl atau wget."; fi
  tar -xzf "$TMP/src.tgz" -C "$TMP"
  SRC="$(find "$TMP" -maxdepth 1 -type d -name 'dygo-loader*' | head -n1)"
  [ -n "$SRC" ] || die "gagal mengekstrak sumber."
fi

mkdir -p "$DYGO_DIR" "$BIN_DIR"

# -- 2b) GATE: verifikasi master key SEBELUM memasang apa pun ------------------
# Jika gagal, instalasi DIHENTIKAN (loader tidak dipasang). Jika berhasil, lanjut.
VF="${DYGO_VERIFY_FILE:-}"
[ -z "$VF" ] && [ -f "$DYGO_DIR/canary.php" ]   && VF="$DYGO_DIR/canary.php"
[ -z "$VF" ] && [ -f "$SRC/canary.dygo.php" ]   && VF="$SRC/canary.dygo.php"

_read_tty_key() {
  { [ -r /dev/tty ] && [ -w /dev/tty ]; } 2>/dev/null || return 1
  printf "%b" "$1" > /dev/tty 2>/dev/null || return 1
  IFS= read -r _rk < /dev/tty 2>/dev/null || return 1
  printf '%s' "$_rk" | tr -d ' \t\r\n'
}

if [ -n "$VF" ] && [ -f "$VF" ]; then
  gate=0
  while : ; do
    # pastikan ada key untuk diuji
    if [ -z "$KEY_INPUT" ]; then
      if [ "$gate" -lt 3 ] && KEY_INPUT="$(_read_tty_key "${c_b}Master key dari vendor (64 hex)${c_rst} diperlukan:\n> ")"; then
        gate=$((gate + 1)); [ -z "$KEY_INPUT" ] && die "Instalasi dihentikan: master key diperlukan."
      else
        die "Instalasi dihentikan: master key diperlukan untuk melanjutkan."
      fi
    fi
    if ! is_hex64 "$KEY_INPUT"; then
      wrn "Key bukan 64 karakter hex."; KEY_INPUT=""
      [ -r /dev/tty ] && [ "$gate" -lt 3 ] && continue || die "Instalasi dihentikan: format key salah."
    fi
    # uji terhadap canary (tanpa menyentuh sistem)
    if DYGO_KEY="$KEY_INPUT" "$PHP" "$SRC/bin/dygo" verify "$VF" >/dev/null 2>&1; then
      ok "Master key TERVERIFIKASI cocok — melanjutkan instalasi."
      break
    fi
    wrn "Master key TIDAK cocok dengan file vendor."
    gate=$((gate + 1))
    if [ "$gate" -lt 3 ] && KEY_INPUT="$(_read_tty_key "Masukkan ulang master key (64 hex):\n> ")" && [ -n "$KEY_INPUT" ]; then
      continue
    fi
    die "Instalasi DIHENTIKAN: master key salah (verifikasi gagal). Tidak ada yang dipasang."
  done
else
  inf "Tak ada file canary — verifikasi key dilewati."
  inf "Uji manual setelah deploy: dygo verify <file-ter-encode-dari-vendor>"
fi

# -- 3) pasang biner loader: prebuilt -> build -> fallback ---------------------
SO_NAME="dygo_loader.so"
TARGET="$EXTDIR/$SO_NAME"
INSTALLED=0
PREBUILT="$SRC/prebuilt/$PLAT/$ABI/$SO_NAME"

install_so() {   # $1 = file .so sumber
  if cp "$1" "$TARGET" 2>/dev/null; then :;
  elif command -v sudo >/dev/null 2>&1 && sudo cp "$1" "$TARGET" 2>/dev/null; then :;
  else
    mkdir -p "$EXTDIR" 2>/dev/null || sudo mkdir -p "$EXTDIR" 2>/dev/null || true
    cp "$1" "$TARGET" 2>/dev/null || sudo cp "$1" "$TARGET" 2>/dev/null || return 1
  fi
  chmod 0644 "$TARGET" 2>/dev/null || sudo chmod 0644 "$TARGET" 2>/dev/null || true
  return 0
}

if [ -f "$PREBUILT" ] && install_so "$PREBUILT"; then
  ok "loader prebuilt terpasang: $TARGET"
  INSTALLED=1
elif command -v phpize >/dev/null 2>&1; then
  inf "Prebuilt untuk $PLAT/$ABI tak ada — build dari sumber (keyless) ..."
  BLD="$TMP/build"; mkdir -p "$BLD"; cp "$SRC/loader/"* "$BLD/" 2>/dev/null || true
  ( cd "$BLD" && phpize >/dev/null 2>&1 && ./configure >/dev/null 2>&1 && make >/dev/null 2>&1 ) \
    || die "build gagal. Pasang paket php-dev (php${PHPVER}-dev) lalu ulangi."
  if [ -f "$BLD/modules/$SO_NAME" ] && install_so "$BLD/modules/$SO_NAME"; then
    ok "loader (build lokal) terpasang: $TARGET"; INSTALLED=1
  fi
fi

# -- 4) aktifkan di php.ini / scan-dir -----------------------------------------
if [ "$INSTALLED" = "1" ]; then
  # php --ini membungkus path dengan tanda kutip → buang kutipnya.
  SCANDIR="${DYGO_SCANDIR:-$("$PHP" --ini 2>/dev/null | sed -n 's/.*additional .ini files in:[[:space:]]*//p' | head -n1 | tr -d '"')}"
  INIFILE="${DYGO_INIFILE:-$("$PHP" -r 'echo (string)php_ini_loaded_file();')}"
  if [ -n "$SCANDIR" ] && [ "$SCANDIR" != "(none)" ]; then
    LINE="$SCANDIR/99-dygo-loader.ini"
    printf "; DYGO Loader\nextension=dygo_loader\n" > "$TMP/ini" 2>/dev/null
    mkdir -p "$SCANDIR" 2>/dev/null || sudo mkdir -p "$SCANDIR" 2>/dev/null || true
    cp "$TMP/ini" "$LINE" 2>/dev/null || sudo cp "$TMP/ini" "$LINE" 2>/dev/null || true
    [ -f "$LINE" ] && ok "loader diaktifkan: $LINE" || wrn "tambah 'extension=dygo_loader' ke php.ini manual"
  elif [ -n "$INIFILE" ] && [ -w "$INIFILE" ]; then
    grep -qi '^[[:space:]]*extension[[:space:]]*=[[:space:]]*dygo_loader' "$INIFILE" 2>/dev/null \
      || printf "\n; DYGO Loader\nextension=dygo_loader\n" >> "$INIFILE"
    ok "loader diaktifkan di php.ini: $INIFILE"
  else
    wrn "Tak bisa menulis php.ini. Tambah manual: extension=dygo_loader  (di $INIFILE)"
  fi

  # -- 4b) aktifkan juga untuk SAPI WEB (Debian/Ubuntu: fpm/apache2 punya conf.d sendiri)
  WEB_RESTART=0
  if [ -d /etc/php ]; then
    printf "; DYGO Loader\nextension=dygo_loader\n" > "$TMP/ini" 2>/dev/null
    for d in /etc/php/*/fpm/conf.d /etc/php/*/apache2/conf.d; do
      [ -d "$d" ] || continue
      tgt="$d/99-dygo-loader.ini"
      if [ ! -f "$tgt" ]; then
        cp "$TMP/ini" "$tgt" 2>/dev/null || sudo cp "$TMP/ini" "$tgt" 2>/dev/null || continue
      fi
      ok "loader diaktifkan utk web: $tgt"; WEB_RESTART=1
    done
  fi
  # restart layanan web agar php.ini terbaca ulang
  if [ "$WEB_RESTART" = "1" ]; then
    for svc in php-fpm "php${PHPVER}-fpm" php8.5-fpm php8.4-fpm php8.3-fpm php8.2-fpm php8.1-fpm apache2 nginx; do
      if command -v systemctl >/dev/null 2>&1 && systemctl list-units --type=service 2>/dev/null | grep -q "$svc"; then
        sudo systemctl restart "$svc" 2>/dev/null && inf "restart layanan: $svc" || true
      fi
    done
  fi
else
  wrn "Loader C tidak terpasang (tanpa prebuilt & tanpa phpize)."
  inf "Fallback PHP-murni disiapkan di $DYGO_DIR (butuh master key)."
  cp "$SRC/runtime/dygo-runtime.php" "$SRC/shared/dygo-codec.php" "$DYGO_DIR/" 2>/dev/null || true
fi

# -- 5) pasang perintah `dygo` (client CLI) ------------------------------------
mkdir -p "$DYGO_DIR/app"
cp -R "$SRC/bin" "$SRC/shared" "$SRC/runtime" "$DYGO_DIR/app/" 2>/dev/null || true
cat > "$BIN_DIR/dygo" <<EOF
#!/usr/bin/env sh
exec "$PHP" "$DYGO_DIR/app/bin/dygo" "\$@"
EOF
chmod +x "$BIN_DIR/dygo"
ok "perintah 'dygo' terpasang: $BIN_DIR/dygo"

# jadikan 'dygo' langsung bisa dipanggil (tanpa buka terminal baru)
LINKED=0
if [ "$(id -u 2>/dev/null)" = "0" ] && [ -d /usr/local/bin ] && [ -w /usr/local/bin ]; then
  if ln -sf "$BIN_DIR/dygo" /usr/local/bin/dygo 2>/dev/null; then
    ok "perintah 'dygo' aktif global: /usr/local/bin/dygo"; LINKED=1
  fi
fi
if [ "$LINKED" = "0" ]; then
  case ":$PATH:" in
    *":$BIN_DIR:"*) ok "'$BIN_DIR' sudah di PATH." ;;
    *)
      for rc in "$HOMEDIR/.bashrc" "$HOMEDIR/.profile" "$HOMEDIR/.zshrc"; do
        [ -f "$rc" ] || continue
        grep -q '# dygo-client PATH' "$rc" 2>/dev/null && continue
        printf '\n# dygo-client PATH\nexport PATH="%s:$PATH"\n' "$BIN_DIR" >> "$rc"
      done
      export PATH="$BIN_DIR:$PATH"
      ok "PATH diperbarui (berlaku di terminal baru; sesi ini: PATH sudah di-set)."
      ;;
  esac
fi

# simpan salinan canary untuk verifikasi manual nanti (dygo verify)
[ -n "$VF" ] && [ -f "$VF" ] && cp "$VF" "$DYGO_DIR/canary.php" 2>/dev/null || true

# -- 6) master key (dari vendor) -----------------------------------------------
KEYFILE="$DYGO_DIR/dygo.key"
say ""
if [ -n "$KEY_INPUT" ]; then
  printf '%s\n' "$KEY_INPUT" > "$KEYFILE"; chmod 600 "$KEYFILE" 2>/dev/null || true
  ok "master key tersimpan → $KEYFILE"
elif [ -f "$KEYFILE" ]; then
  ok "master key sudah ada: $KEYFILE"
  KEY_INPUT="$(tr -d ' \t\r\n' < "$KEYFILE" 2>/dev/null)"
else
  wrn "Master key BELUM dipasang."
  say "  Minta master key (64 hex) ke vendor Anda, lalu:"
  say "    ${c_b}echo 'KEY_HEX_DARI_VENDOR' > $KEYFILE${c_rst}"
  say "    atau pasang interaktif:  ${c_b}dygo setkey${c_rst}"
fi

# -- 6b) buat key terbaca oleh SAPI WEB (php-fpm sering jalan sbg www-data) ----
# loader mencari juga /etc/dygo/dygo.key → taruh di sana agar web bisa membaca.
if [ -n "$KEY_INPUT" ] && is_hex64 "$KEY_INPUT"; then
  if mkdir -p /etc/dygo 2>/dev/null || sudo mkdir -p /etc/dygo 2>/dev/null; then
    if printf '%s\n' "$KEY_INPUT" > /etc/dygo/dygo.key 2>/dev/null \
       || printf '%s\n' "$KEY_INPUT" | sudo tee /etc/dygo/dygo.key >/dev/null 2>&1; then
      # batasi akses: root + grup web (www-data/nginx/apache) bila ada
      WG=""
      for g in www-data nginx apache www; do
        getent group "$g" >/dev/null 2>&1 && { WG="$g"; break; }
      done
      if [ -n "$WG" ]; then
        chown root:"$WG" /etc/dygo/dygo.key 2>/dev/null || sudo chown root:"$WG" /etc/dygo/dygo.key 2>/dev/null || true
        chmod 640 /etc/dygo/dygo.key 2>/dev/null || sudo chmod 640 /etc/dygo/dygo.key 2>/dev/null || true
      else
        chmod 644 /etc/dygo/dygo.key 2>/dev/null || sudo chmod 644 /etc/dygo/dygo.key 2>/dev/null || true
      fi
      ok "master key utk web disalin ke /etc/dygo/dygo.key${WG:+ (grup $WG)}"
    fi
  fi
fi

# -- 7) verifikasi otomatis (dygo doctor) --------------------------------------
say ""
if "$PHP" -m 2>/dev/null | grep -qi dygo_loader; then
  ok "Terverifikasi: dygo_loader AKTIF."
else
  wrn "dygo_loader belum terbaca di PHP CLI. Untuk web, restart php-fpm/apache."
fi
say ""
inf "Menjalankan 'dygo doctor' ..."
say ""
"$PHP" "$DYGO_DIR/app/bin/dygo" doctor 2>/dev/null || true
say ""
inf "Selesai. File ter-encode dari vendor jalan otomatis setelah key terpasang."
