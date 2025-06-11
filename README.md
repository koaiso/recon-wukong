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
