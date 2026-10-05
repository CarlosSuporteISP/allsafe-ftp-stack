#!/usr/bin/env bash
# Gera os arquivos da marca que o painel usa (web/marca/) a partir das fontes em web/marca/fonte/:
# o ícone do navegador, o símbolo do topo e a logo da tela de entrada. As fontes não são alteradas.
# A arte é escura em fundo transparente e o painel tem fundo escuro: cada arquivo sai sobre uma
# placa clara de cantos arredondados, que aparece igual em aba clara ou escura do navegador.
# Só roda quando a marca muda: os arquivos gerados ficam no repositório e a instalação não usa
# este script. Precisa do ImageMagick 7 (comando magick) no computador de quem troca a marca.
set -Eeuo pipefail
root_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root_dir"
die() { echo "ERRO: $*" >&2; exit 1; }

fonte=web/marca/fonte
destino=web/marca
logo="$fonte/allsafe-logo-2048.png"        # logo completa: símbolo e nome
simbolo="$fonte/allsafe-simbolo-512.png"   # só o símbolo
placa="${MARCA_PLACA:-#ffffff}"            # cor da placa atrás da arte

command -v magick >/dev/null 2>&1 || die "o ImageMagick 7 (comando magick) não está instalado neste computador."
[[ -f "$logo" && -f "$simbolo" ]] || die "faltam as fontes $logo e $simbolo."
[[ "$placa" =~ ^#[0-9a-fA-F]{6}$ ]] || die "MARCA_PLACA aceita só cor no formato #rrggbb."

tmp="$(mktemp -d "${TMPDIR:-/tmp}/allsafe-marca.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

# <fonte> <lado em pixels> <arquivo>: a arte recortada na borda, centralizada na placa com 10% de margem.
# O desenho é montado em 1024 pixels e reduzido no fim, para a borda da placa sair lisa em qualquer tamanho.
# 128 cores em 8 bits bastam para uma arte de uma cor só sobre a placa: a logo cai de 93 KB para 7 KB.
gerar() {
  magick -size 1024x1024 xc:none -fill "$placa" -draw 'roundrectangle 0,0 1023,1023 184,184' \
    \( "$1" -trim +repage -resize 820x820 \) -gravity center -composite \
    -resize "$2x$2" -colors 128 -depth 8 -strip -define png:compression-level=9 -define png:exclude-chunks=date,time "$3"
}

gerar "$simbolo" 16 "$tmp/16.png"
gerar "$simbolo" 32 "$destino/icone-32.png"
gerar "$simbolo" 48 "$tmp/48.png"
gerar "$simbolo" 64 "$destino/simbolo-64.png"
gerar "$simbolo" 180 "$destino/apple-touch-icon.png"
gerar "$simbolo" 192 "$destino/icone-192.png"
gerar "$logo" 320 "$destino/logo-320.png"
magick "$tmp/16.png" "$destino/icone-32.png" "$tmp/48.png" "$destino/favicon.ico"

chmod 0644 "$destino"/*.png "$destino/favicon.ico"
for arquivo in favicon.ico icone-32.png icone-192.png apple-touch-icon.png simbolo-64.png logo-320.png; do
  printf '%s: %s bytes\n' "$destino/$arquivo" "$(wc -c < "$destino/$arquivo")"
done
echo "Marca gerada em $destino/. Rode ./deploy.sh para o painel passar a usar."
