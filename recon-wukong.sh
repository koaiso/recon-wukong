#!/bin/bash

echo "🔥 WUKONG RECON FRAMEWORK 🔥"
echo "Target domain: $1"
echo

# CEK DOMAIN INPUT
if [ -z "$1" ]; then
    echo "Usage: ./recon-wukong.sh domain.com"
    exit 1
fi

DOMAIN=$1

# CEK DAN BUAT PATTERN GF
if [ ! -d ~/.config/gf ]; then
    echo "🛠️  Installing GF patterns..."
    git clone https://github.com/tomnomnom/gf ~/.gf
    mkdir -p ~/.config/gf
    cp ~/.gf/examples/* ~/.config/gf
fi

# CEK TEMPLATE NUCLEI
if [ ! -d ~/.config/nuclei-templates ]; then
    echo "🛠️  Installing Nuclei templates..."
    nuclei -update-templates
fi

echo "🔍 [1] Subdomain enumeration..."
subfinder -d $DOMAIN -silent > subs.txt
assetfinder --subs-only $DOMAIN >> subs.txt
sort -u subs.txt -o subs.txt

echo "🌐 [2] Live host checking..."
cat subs.txt | httpx -silent -status-code -title -tech-detect -mc 200 > live.txt
cut -d " " -f 1 live.txt > live-clean.txt

echo "🧠 [3] Collecting historical endpoints..."
cat live-clean.txt | gau > endpoints.txt

echo "🎯 [4] Filtering for SQLi and XSS..."
cat endpoints.txt | grep "=" | sort -u > params.txt

if [ -s params.txt ]; then
    cat params.txt | gf sqli > sqli.txt 2>/dev/null
    cat params.txt | gf xss > xss.txt 2>/dev/null
else
    echo "⚠️  No parameters found to analyze."
fi

echo "⚡ [5] Running nuclei scan on live hosts..."

if [ -s live-clean.txt ]; then
    nuclei -l live-clean.txt -t vulnerabilities/ -severity low,medium,high,critical -silent -o nuclei-result.txt
else
    echo "⚠️  No live hosts found. Skipping nuclei scan."
fi

echo "🧪 [6] Running sqlmap test (top 5 SQLi candidates)..."

if [ -s sqli.txt ]; then
    head -n 5 sqli.txt | while read url; do
        echo "→ Testing: $url"
        sqlmap -u "$url" --batch --random-agent --level=5 --risk=3 --timeout=15 --technique=BU --text-only --output-dir=sqlmap-output/
    done
else
    echo "⚠️  No SQLi candidates found."
fi

echo
echo "✅ Recon selesai! Hasil disimpan di:"
ls -1 *.txt 2>/dev/null
[ -d sqlmap-output ] && echo "📁 sqlmap-output/"
