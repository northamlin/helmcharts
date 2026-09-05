#!/bin/bash
# Publish the chart catalog to the root of this repo.
#
# ArgoCD reaches this repo as a plain Helm repository at
# https://raw.githubusercontent.com/northamlin/helmcharts/master/ -- that URL is
# hardcoded in helmdeployer/src/generator.ts and whitelisted in the eu-service
# AppProject on eu-upcloud-1. So index.yaml AND the .tgz files it names both have to
# sit in the repo root and be committed. They were not, which is why every chart URL
# 404'd while index.yaml itself resolved fine.
#
# The index is built in a staging directory on purpose: `helm repo index .` recurses,
# so it would otherwise pick up release/ as well and emit duplicate entries plus URLs
# pointing into a directory the platform does not read.
set -euo pipefail

cd "$(dirname "$0")"
staging=$(mktemp -d)
trap 'rm -rf "$staging"' EXIT

for dir in */; do
  [[ "$dir" == "dockers/" || "$dir" == "release/" ]] && continue
  [[ -f "${dir}Chart.yaml" ]] || continue
  helm package "$dir" -d .
done

cp ./*.tgz "$staging"/
helm repo index "$staging"
cp "$staging"/index.yaml ./index.yaml

