#!/usr/bin/env bash

[ "${DOMAIN}" = '' ] && echo "❌ 'DOMAIN' env var not set" && exit 1

[ "${DOCKER_PASSWORD}" = '' ] && echo "❌ 'DOCKER_PASSWORD' env var not set" && exit 1
[ "${DOCKER_USER}" = '' ] && echo "❌ 'DOCKER_USER' env var not set" && exit 1

[ "${GITHUB_REPO_REF}" = '' ] && echo "❌ 'GITHUB_REPO_REF' env var not set" && exit 1

HELM_VERSION="$1"

set -eou pipefail

echo "🚀 Publishing version ${HELM_VERSION}"

yq eval ".version = \"${HELM_VERSION}\"" ./chart/Chart.yaml >"Chart.tmp"
mv "Chart.tmp" ./chart/Chart.yaml

echo "📝 Generating Documentation"
helm-docs
echo "✅ Documentation Generated"

onExit() {
  rc="$?"
  rm -rf ./uploads
  if [ "$rc" = '0' ]; then
    echo "✅ Successfully published helm chart"
  else
    echo "❌ Failed to publish helm chart"
  fi
}
trap onExit EXIT

echo "🔐 Logging into docker registry..."
echo "${DOCKER_PASSWORD}" | helm registry login "${DOMAIN}" -u "${DOCKER_USER}" --password-stdin

cd ./chart || exit

# packaging helm chart
echo "📦 Packaging helm chart..."
helm dependency build
helm package . -u --version "${HELM_VERSION}" -d ./uploads

echo "📤 Pushing helm chart..."
for filename in ./uploads/*.tgz; do
  OCI_REF="$(echo "oci://${DOMAIN}/${GITHUB_REPO_REF}" | tr '[:upper:]' '[:lower:]')"
  echo "📤 Pushing ${filename} to ${OCI_REF}"
  helm push "$filename" "${OCI_REF}"
done
