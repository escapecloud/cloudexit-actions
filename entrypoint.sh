#!/usr/bin/env bash

set -euo pipefail

get_input() {
  local underscore_name="$1"
  local hyphen_name="$2"

  local value="${!underscore_name:-}"
  if [[ -z "${value}" && -n "${hyphen_name}" ]]; then
    value="$(printenv "${hyphen_name}" 2>/dev/null || true)"
  fi

  printf "%s" "${value}"
}

provider="$(printf '%s' "$(get_input INPUT_PROVIDER "INPUT_PROVIDER")" | tr '[:upper:]' '[:lower:]')"
auth_mode="$(printf '%s' "$(get_input INPUT_AUTH_MODE "INPUT_AUTH-MODE")" | tr '[:upper:]' '[:lower:]')"
cloudexit_ref="$(get_input INPUT_VERSION "INPUT_VERSION")"
cloudexit_ref="${cloudexit_ref:-v1.1.1}"
exit_strategy="$(get_input INPUT_EXIT_STRATEGY "INPUT_EXIT-STRATEGY")"
assessment_type="$(get_input INPUT_ASSESSMENT_TYPE "INPUT_ASSESSMENT-TYPE")"
input_host="$(get_input INPUT_HOST "INPUT_HOST")"
input_key="$(get_input INPUT_KEY "INPUT_KEY")"

if [[ "${provider}" != "aws" && "${provider}" != "azure" ]]; then
  echo "Invalid provider: '${provider}'. Expected 'aws' or 'azure'." >&2
  exit 2
fi

if [[ "${auth_mode}" != "static" && "${auth_mode}" != "oidc" ]]; then
  echo "Invalid auth-mode: '${auth_mode}'. Expected 'static' or 'oidc'." >&2
  exit 2
fi

if [[ "${exit_strategy}" != "1" && "${exit_strategy}" != "3" ]]; then
  echo "Invalid exit-strategy: '${exit_strategy}'. Expected 1 or 3." >&2
  exit 2
fi

if [[ "${assessment_type}" != "1" && "${assessment_type}" != "2" ]]; then
  echo "Invalid assessment-type: '${assessment_type}'. Expected 1 or 2." >&2
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

export ESC_EXIT_STRATEGY="${exit_strategy}"
export ESC_ASSESSMENT_TYPE="${assessment_type}"
export HOST="${input_host:-}"
export KEY="${input_key:-}"

if [[ "${provider}" == "aws" ]]; then
  if [[ -z "${AWS_DEFAULT_REGION:-}" && -z "${AWS_REGION:-}" ]]; then
    echo "AWS_DEFAULT_REGION (or AWS_REGION) is required for AWS runs." >&2
    exit 2
  fi
  if [[ "${auth_mode}" == "static" ]]; then
    if [[ -z "${AWS_ACCESS_KEY_ID:-}" || -z "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
      echo "AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY are required for AWS static mode." >&2
      exit 2
    fi
  fi
  if [[ "${auth_mode}" == "oidc" ]]; then
    if [[ -z "${AWS_ACCESS_KEY_ID:-}" || -z "${AWS_SECRET_ACCESS_KEY:-}" || -z "${AWS_SESSION_TOKEN:-}" ]]; then
      echo "AWS OIDC mode requires AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, and AWS_SESSION_TOKEN (typically from aws-actions/configure-aws-credentials)." >&2
      exit 2
    fi
  fi
  python main.py aws --non-interactive
fi

if [[ "${provider}" == "azure" ]]; then
  if [[ -z "${ESC_SUBSCRIPTION_ID:-}" || -z "${ESC_RESOURCE_GROUP:-}" ]]; then
    echo "ESC_SUBSCRIPTION_ID and ESC_RESOURCE_GROUP are required for Azure runs." >&2
    exit 2
  fi
  if [[ "${auth_mode}" == "static" ]]; then
    if [[ -z "${AZURE_TENANT_ID:-}" || -z "${AZURE_CLIENT_ID:-}" || -z "${AZURE_CLIENT_SECRET:-}" ]]; then
      echo "Azure static mode requires AZURE_TENANT_ID, AZURE_CLIENT_ID, and AZURE_CLIENT_SECRET." >&2
      exit 2
    fi
  fi
  if [[ "${auth_mode}" == "oidc" ]]; then
    if [[ -z "${AZURE_TENANT_ID:-}" || -z "${AZURE_CLIENT_ID:-}" ]]; then
      echo "Azure OIDC mode requires AZURE_TENANT_ID and AZURE_CLIENT_ID." >&2
      exit 2
    fi
    if [[ -z "${AZURE_FEDERATED_TOKEN_FILE:-}" ]]; then
      echo "Azure OIDC mode requires AZURE_FEDERATED_TOKEN_FILE (typically from azure/login)." >&2
      exit 2
    fi
    if [[ ! -f "${AZURE_FEDERATED_TOKEN_FILE}" ]]; then
      mapped_token_file="${AZURE_FEDERATED_TOKEN_FILE/#\/home\/runner\/work\/_temp\//\/github\/runner_temp\/}"
      if [[ -f "${mapped_token_file}" ]]; then
        export AZURE_FEDERATED_TOKEN_FILE="${mapped_token_file}"
      else
        echo "AZURE_FEDERATED_TOKEN_FILE path is not accessible inside action container: ${AZURE_FEDERATED_TOKEN_FILE}" >&2
        exit 2
      fi
    fi
  fi

  python main.py azure --non-interactive
fi

latest_report_dir="$(ls -1dt reports/* 2>/dev/null | head -n 1 || true)"
if [[ -n "${latest_report_dir:-}" && -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "report-dir=cloudexit/${latest_report_dir}" >> "${GITHUB_OUTPUT}"
fi
