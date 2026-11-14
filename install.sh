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
case ":$PATH:" in *":$BIN_DIR:"*) : ;; *) wrn "Tambahkan ke PATH: export PATH=\"$BIN_DIR:\$PATH\"";; esac

# -- 6) master key (dari vendor) -----------------------------------------------
KEYFILE="$DYGO_DIR/dygo.key"
say ""
if [ -n "${DYGO_KEY:-}" ]; then
  printf '%s\n' "$DYGO_KEY" > "$KEYFILE"; chmod 600 "$KEYFILE" 2>/dev/null || true
  ok "master key tersimpan dari env DYGO_KEY → $KEYFILE"
elif [ -f "$KEYFILE" ]; then
  ok "master key sudah ada: $KEYFILE"
else
  wrn "Master key BELUM dipasang."
  say "  Minta master key (64 hex) ke vendor Anda, lalu salah satu:"
  say "    ${c_b}echo 'KEY_HEX_DARI_VENDOR' > $KEYFILE${c_rst}"
  say "    atau set env sebelum menjalankan PHP:  export DYGO_KEY=KEY_HEX"
fi

# -- 7) verifikasi -------------------------------------------------------------
say ""
if "$PHP" -m 2>/dev/null | grep -qi dygo_loader; then
  ok "Terverifikasi: dygo_loader AKTIF."
else
  inf "Jalankan: dygo doctor   (untuk web, restart php-fpm/apache)."
fi
inf "Selesai. File ter-encode dari vendor kini jalan otomatis setelah key terpasang."
