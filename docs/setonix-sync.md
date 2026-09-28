# Working on Setonix

Working copy: `/scratch/pawsey1168/llenzo/carlia`, account `pawsey1168`.

Scratch is purged on a 21-day cycle and is not backed up. This repository holds scripts
and metadata only; `raw/` and `logs/` are gitignored and exist on scratch alone.

## Setup

The repository is public, so Setonix clones and pulls over HTTPS with no credentials.
Push from your workstation, pull on Setonix.

Into a directory that already holds downloaded data:

```bash
cd /scratch/pawsey1168/llenzo/carlia
git init
git config user.email "leon.lenzo@curtin.edu.au"
git config user.name  "Leon Lenzo"
git remote add origin https://github.com/LeonLenzo/carlia-rnaseq.git
git fetch origin main
git reset --mixed origin/main
git branch -M main
git branch --set-upstream-to=origin/main main
```

`git reset --mixed` rather than `checkout`, so the existing `raw/` is left untouched.

## Partitions

Only the `copy` partition has external network access. Downloads and any other transfer
out to the internet must run there, not on `work` and not on the login node.
