#!/usr/bin/env bash
set -uo pipefail

usage() {
  cat <<'HELP'
recon-wukong — scoped reconnaissance

Usage: ./recon-wukong.sh domain.tld [--output DIR] [--rate N] [--crawl] [--nuclei]

  --output DIR  Results directory (default: results/<domain>/<UTC timestamp>)
  --rate N      Maximum requests per second for httpx/nuclei (default: 10)
  --crawl       Crawl in-scope live hosts with Katana (off by default)
  --nuclei      Run Nuclei on in-scope live URLs (off by default)
  -h, --help    Show this help

Run only against assets you are authorized to assess. Review program scope
and scan restrictions before using --nuclei.
HELP
}

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
note() { printf '[+] %s\n' "$*"; }
warn() { printf '[!] %s\n' "$*" >&2; }
count() { wc -l < "$1" | tr -d ' '; }

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
[[ $# -gt 0 ]] || { usage >&2; exit 2; }
if [[ $1 == -h || $1 == --help ]]; then usage; exit 0; fi
target=$1; shift
output=''; rate=10; run_nuclei=false; run_crawl=false
while (($#)); do
  case "$1" in
    --output) (($# >= 2)) || die '--output needs a directory'; output=$2; shift 2 ;;
    --rate) (($# >= 2)) || die '--rate needs a number'; rate=$2; shift 2 ;;
    --nuclei) run_nuclei=true; shift ;;
    --crawl) run_crawl=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
done

command -v python3 >/dev/null || die 'python3 is required'
command -v subfinder >/dev/null || die 'subfinder is required'
command -v httpx >/dev/null || die 'ProjectDiscovery httpx is required'
[[ $rate =~ ^[0-9]+$ ]] && ((rate >= 1 && rate <= 100)) || die '--rate must be 1..100'
domain=$(python3 "$script_dir/tools/scope.py" validate "$target") || die 'invalid target domain'
if $run_nuclei; then command -v nuclei >/dev/null || die 'nuclei is required with --nuclei'; fi
if $run_crawl; then command -v katana >/dev/null || die 'katana is required with --crawl'; fi

[[ -n $output ]] || output="results/$domain/$(date -u +%Y%m%dT%H%M%SZ)"
[[ ! -e $output ]] || die "output already exists: $output"
mkdir -p -- "$output" || die "cannot create output directory: $output"
output=$(cd -- "$output" && pwd)
tmp=$(mktemp -d) || die 'cannot create temporary directory'
trap 'rm -rf -- "$tmp"' EXIT

note "target: $domain"
note "output: $output"
printf '%s\n' "$domain" > "$tmp/hosts.raw"
if ! subfinder -d "$domain" -silent >> "$tmp/hosts.raw"; then
  warn 'subfinder returned an error; results may be incomplete'
fi
if command -v assetfinder >/dev/null; then
  if ! assetfinder --subs-only "$domain" >> "$tmp/hosts.raw"; then
    warn 'assetfinder returned an error; results may be incomplete'
  fi
else
  warn 'assetfinder missing; using subfinder only'
fi
python3 "$script_dir/tools/scope.py" hosts "$domain" < "$tmp/hosts.raw" | LC_ALL=C sort -u > "$output/hosts.txt"
note "hosts: $(count "$output/hosts.txt")"

# Keep every responding status, including 301/302/401/403/500.
if ! httpx -l "$output/hosts.txt" -silent -status-code -title -rl "$rate" > "$tmp/httpx.raw"; then
  warn 'httpx returned an error; live host results may be incomplete'
fi
python3 "$script_dir/tools/scope.py" live "$domain" < "$tmp/httpx.raw" | LC_ALL=C sort -u > "$output/live-urls.txt"
if [[ -s $output/live-urls.txt ]]; then
  # Only retain detailed rows that correspond to verified in-scope URLs.
  python3 "$script_dir/tools/filter_httpx.py" "$output/live-urls.txt" < "$tmp/httpx.raw" > "$output/live.txt"
else
  : > "$output/live.txt"
fi
note "live URLs: $(count "$output/live-urls.txt")"

: > "$tmp/archive.raw"
if command -v gau >/dev/null; then
  if ! gau --subs "$domain" > "$tmp/archive.raw"; then
    warn 'gau returned an error; archived URLs may be incomplete'
  fi
else
  warn 'gau missing; archived URLs skipped'
fi
python3 "$script_dir/tools/scope.py" urls "$domain" < "$tmp/archive.raw" | LC_ALL=C sort -u > "$output/archived.txt"
: > "$output/crawled.txt"
if $run_crawl; then
  if [[ -s $output/live-urls.txt ]]; then
    note "katana: depth 2, rate $rate/s"
    if ! katana -list "$output/live-urls.txt" -depth 2 -rl "$rate" -fs fqdn -jc -silent > "$tmp/crawl.raw"; then
      warn 'katana returned an error; crawl results may be incomplete'
    fi
    python3 "$script_dir/tools/scope.py" urls "$domain" < "$tmp/crawl.raw" | LC_ALL=C sort -u > "$output/crawled.txt"
  else
    warn 'no live URLs; katana skipped'
  fi
fi
cat "$output/archived.txt" "$output/crawled.txt" | LC_ALL=C sort -u > "$output/endpoints.txt"
python3 "$script_dir/tools/scope.py" params "$domain" < "$output/endpoints.txt" > "$output/params.txt"
python3 "$script_dir/tools/scope.py" js "$domain" < "$output/endpoints.txt" > "$output/js.txt"
python3 "$script_dir/tools/scope.py" api "$domain" < "$output/endpoints.txt" > "$output/api.txt"
python3 "$script_dir/tools/scope.py" keys "$domain" < "$output/params.txt" > "$output/param-keys.tsv"
note "archive: $(count "$output/archived.txt"); crawl: $(count "$output/crawled.txt"); parameters: $(count "$output/params.txt"); JS: $(count "$output/js.txt")"

if $run_nuclei; then
  : > "$output/nuclei.txt"
  if [[ -s $output/live-urls.txt ]]; then
    note "nuclei: rate $rate/s, severity medium/high/critical"
    if ! nuclei -l "$output/live-urls.txt" -severity medium,high,critical -rate-limit "$rate" -silent -o "$output/nuclei.txt"; then
      warn 'nuclei returned an error; check its output and installation'
    fi
  else
    warn 'no live URLs; nuclei skipped'
  fi
fi
note 'done — collected endpoints are leads, not verified vulnerabilities'
