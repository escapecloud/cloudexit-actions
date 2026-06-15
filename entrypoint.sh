#!/usr/bin/env bash

set -euo pipefail

provider="$(printf '%s' "${INPUT_PROVIDER:-}" | tr '[:upper:]' '[:lower:]')"
auth_mode="$(printf '%s' "${INPUT_AUTH_MODE:-}" | tr '[:upper:]' '[:lower:]')"
cloudexit_ref="${INPUT_VERSION:-v1.0.8}"

if [[ "${provider}" != "aws" && "${provider}" != "azure" ]]; then
  echo "Invalid provider: '${provider}'. Expected 'aws' or 'azure'." >&2
  exit 2
fi

if [[ "${auth_mode}" != "static" ]]; then
  echo "Invalid auth-mode: '${auth_mode}'. This action version supports only 'static'." >&2
  exit 2
fi

if [[ "${INPUT_EXIT_STRATEGY:-}" != "1" && "${INPUT_EXIT_STRATEGY:-}" != "3" ]]; then
  echo "Invalid exit-strategy: '${INPUT_EXIT_STRATEGY:-}'. Expected 1 or 3." >&2
  exit 2
fi

if [[ "${INPUT_ASSESSMENT_TYPE:-}" != "1" && "${INPUT_ASSESSMENT_TYPE:-}" != "2" ]]; then
  echo "Invalid assessment-type: '${INPUT_ASSESSMENT_TYPE:-}'. Expected 1 or 2." >&2
  exit 2
fi

workspace="${GITHUB_WORKSPACE:-/github/workspace}"
mkdir -p "${workspace}"
cd "${workspace}"

rm -rf cloudexit
git init -q cloudexit
cd cloudexit
git remote add origin https://github.com/escapecloud/cloudexit.git
git fetch --depth 1 origin "${cloudexit_ref}"
git checkout --detach -q FETCH_HEAD

python -m pip install --upgrade pip
pip install -r requirements.txt

export ESC_EXIT_STRATEGY="${INPUT_EXIT_STRATEGY}"
export ESC_ASSESSMENT_TYPE="${INPUT_ASSESSMENT_TYPE}"
export HOST="${INPUT_HOST:-}"
export KEY="${INPUT_KEY:-}"

if [[ "${provider}" == "aws" ]]; then
  if [[ -z "${AWS_DEFAULT_REGION:-}" && -z "${AWS_REGION:-}" ]]; then
    echo "AWS_DEFAULT_REGION (or AWS_REGION) is required for AWS runs." >&2
    exit 2
  fi
  python main.py aws --non-interactive
fi

if [[ "${provider}" == "azure" ]]; then
  if [[ -z "${ESC_SUBSCRIPTION_ID:-}" || -z "${ESC_RESOURCE_GROUP:-}" ]]; then
    echo "ESC_SUBSCRIPTION_ID and ESC_RESOURCE_GROUP are required for Azure runs." >&2
    exit 2
  fi

  python main.py azure --non-interactive
fi

latest_report_dir="$(ls -1dt reports/* 2>/dev/null | head -n 1 || true)"
if [[ -n "${latest_report_dir:-}" && -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "report-dir=cloudexit/${latest_report_dir}" >> "${GITHUB_OUTPUT}"
fi
