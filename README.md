# 🔍 recon-wukong

Automated reconnaissance framework for bug bounty and pentest.  
Built for fast subdomain discovery, endpoint collection, vulnerability detection, and SQLi/XSS identification — all in one script.

---

## ⚙️ Features

- 🛰️ Subdomain enumeration (`subfinder`, `assetfinder`)
- 🌐 Live host check (`httpx`)
- 🧠 Historical endpoint collection (`gau`)
- 🎯 Parameter filtering for SQLi/XSS (`gf`)
- ⚡ Vulnerability scanning (`nuclei`)
- 🧪 SQL injection testing (`sqlmap`)

---

## 🚀 Quick Usage

```bash
./recon-wukong.sh example.com
Output will be saved in the current directory with results such as subs.txt, sqli.txt, xss.txt, and more.
📦 Requirements
Make sure the following tools are installed and added to your $PATH:

Go

subfinder

assetfinder

httpx

gau

gf

nuclei

sqlmap

📁 Output Files
File	Description
subs.txt	Discovered subdomains
live.txt	Live subdomains with HTTP status
endpoints.txt	Archived URLs with parameters
params.txt	Filtered URLs containing parameters
sqli.txt	SQLi parameter candidates (via gf)
xss.txt	XSS parameter candidates (via gf)
nuclei-result.txt	Vulnerability findings (via nuclei)
sqlmap-output/	SQLMap dump results

✨ Author
Developed by @mzhsky (Wukong 🐵)
