# recon-wukong

Alur recon untuk satu domain: temukan subdomain, cek host yang merespons, lalu kumpulkan URL arsip untuk ditriase. Hasil setiap run disimpan terpisah dan dibatasi ke domain yang dimasukkan. Tidak ada instalasi otomatis atau pengujian SQL injection otomatis.

Gunakan hanya pada aset yang memang masuk scope dan boleh diuji. Periksa aturan program sebelum memakai opsi `--nuclei`.

## Kebutuhan

- Bash dan Python 3 (modul standar saja).
- [subfinder](https://github.com/projectdiscovery/subfinder) dan [ProjectDiscovery httpx](https://github.com/projectdiscovery/httpx).
- Opsional: [assetfinder](https://github.com/tomnomnom/assetfinder), [gau](https://github.com/lc/gau) untuk URL historis, [katana](https://github.com/projectdiscovery/katana) untuk crawling, dan [nuclei](https://github.com/projectdiscovery/nuclei) untuk pemindaian yang diaktifkan secara eksplisit.

Pastikan binary tersedia di `PATH` (`command -v subfinder httpx`). Jika Kali menyediakan binary `httpx` yang berbeda, gunakan binary ProjectDiscovery dari instalasi Go dan pastikan direktori bin Go ada di `PATH`.

## Pakai

```bash
git clone https://github.com/koaiso/recon-wukong.git
cd recon-wukong
chmod +x recon-wukong.sh
./recon-wukong.sh example.com
```

Contoh opsi:

```bash
./recon-wukong.sh example.com --output hasil/contoh --rate 5
./recon-wukong.sh example.com --crawl --rate 5
./recon-wukong.sh example.com --nuclei --rate 5
./recon-wukong.sh --help
```

`--rate` membatasi request per detik untuk `httpx`, `katana`, dan `nuclei` (1–100; default 10). `--crawl` menelusuri URL hidup dengan Katana hingga kedalaman 2, memeriksa JavaScript, dan membatasi penelusuran ke hostname awal. `--nuclei` menjalankan template severity medium, high, dan critical pada URL hidup yang lolos pemeriksaan scope. Kedua opsi ini mati secara default; tool tetap melakukan probe HTTP ringan ke host hasil penemuan. `gau` mengambil URL dari arsip publik; endpoint historis belum tentu masih hidup. Scan tidak mengikuti redirect lintas host secara sengaja.

Target harus nama domain biasa seperti `example.com`, bukan URL, wildcard, atau IP. Pencocokan scope memakai batas label DNS: `a.example.com` diterima, tetapi `example.com.evil.org` ditolak. Hasil URL dengan kredensial di bagian host ditolak.

## Berkas hasil

Secara default hasil ditulis ke `results/<domain>/<waktu-UTC>/`:

| Berkas | Isi |
| --- | --- |
| `hosts.txt` | Domain dan subdomain yang lolos scope |
| `live.txt` | Output probe `httpx`, termasuk status selain 200 |
| `live-urls.txt` | URL hidup yang lolos scope |
| `archived.txt` | URL arsip yang lolos scope |
| `crawled.txt` | URL hasil Katana; terisi jika `--crawl` dipakai |
| `endpoints.txt` | Gabungan URL arsip dan crawl yang lolos scope |
| `params.txt` | URL hasil pengumpulan dengan parameter query |
| `param-keys.tsv` | Frekuensi nama parameter |
| `js.txt` | URL berakhiran `.js` |
| `api.txt` | URL dengan path `/api/` atau `/graphql` |
| `nuclei.txt` | Temuan Nuclei, hanya saat `--nuclei` digunakan |

`params.txt`, `js.txt`, dan `api.txt` adalah kandidat untuk pemeriksaan manual, bukan bukti kerentanan. Tool tidak membuat klaim SQLi atau XSS dari pola URL.

## Periksa perubahan

```bash
bash -n recon-wukong.sh
python3 -m unittest discover -s tests -v
```

Ditulis untuk workflow bug bounty Wukong. Saran perbaikan dan laporan masalah bisa dikirim lewat [Issues](https://github.com/koaiso/recon-wukong/issues).
