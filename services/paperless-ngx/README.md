# 📄 Paperless-ngx

OCR paper archive: everything that arrives on paper gets scanned once, OCR-ed
and becomes searchable.

## 📁 Storage

| Path | Where | Why |
| --- | --- | --- |
| documents, consume, export | NAS over CIFS | bulk files, read and written whole |
| Whoosh index, Postgres | `/srv/docker-data` (ext4) | both mmap, which CIFS cannot serve |

Two settings are load-bearing:

* **`PAPERLESS_CONSUMER_POLLING=60`** — inotify does not fire on CIFS. Remove
  it and the drop zone goes permanently deaf, with no error at all.
* **`/mnt/media-smb`, not `/mnt/storage-smb`** — the same share mounted twice,
  `uid=1000` and `uid=0`. This container runs as 1000, so the wrong mount makes
  every write fail.

## 📥 Feeding it

| Route | How |
| --- | --- |
| Phone / PC | drop into the share's `paperless/consume` |
| Subfolder = tag | `consume/Taxes/2026/x.pdf` arrives tagged `Taxes` + `2026` |
| Web UI | drag onto the dashboard |
| Phone app | Paperless Mobile, pointed at the same URL |

Polling means ~60s, not instant. Scan at 300 DPI greyscale, one PDF per
document — 600 DPI quadruples OCR time for no gain on printed text, and
`PAPERLESS_OCR_MODE=auto` leaves an existing text layer alone.

## 💾 Backup

The files being on the NAS covers the disaster case, but the tree carries no
tags, correspondents or dates — those live in Postgres. The exporter captures
both:

```sh
docker exec -u paperless paperless document_exporter /export --delete
```

`/export` sits outside the media root on purpose: an export written inside
`media` registers as orphan files and gets swept into the next one. Restore is
`document_importer /export` on a fresh instance.
