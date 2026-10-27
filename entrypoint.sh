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
cloudexit_ref="${cloudexit_ref:-v2.0.0}"
exit_strategy="$(get_input INPUT_EXIT_STRATEGY "INPUT_EXIT-STRATEGY")"
assessment_type="$(get_input INPUT_ASSESSMENT_TYPE "INPUT_ASSESSMENT-TYPE")"
input_host="$(get_input INPUT_HOST "INPUT_HOST")"
input_key="$(get_input INPUT_KEY "INPUT_KEY")"
egress="$(printf '%s' "$(get_input INPUT_EGRESS "INPUT_EGRESS")" | tr '[:upper:]' '[:lower:]')"
tfstate="$(get_input INPUT_TFSTATE "INPUT_TFSTATE")"
upload="$(printf '%s' "$(get_input INPUT_UPLOAD "INPUT_UPLOAD")" | tr '[:upper:]' '[:lower:]')"
strict="$(printf '%s' "$(get_input INPUT_STRICT "INPUT_STRICT")" | tr '[:upper:]' '[:lower:]')"

if [[ "${provider}" != "aws" && "${provider}" != "azure" ]]; then
  echo "Invalid provider: '${provider}'. Expected 'aws' or 'azure'." >&2
  exit 2
fi

if [[ "${exit_strategy}" != "1" && "${exit_strategy}" != "2" && "${exit_strategy}" != "3" ]]; then
  echo "Invalid exit-strategy: '${exit_strategy}'. Expected 1, 2 or 3." >&2
  exit 2
fi

if [[ "${assessment_type}" != "1" && "${assessment_type}" != "2" ]]; then
  echo "Invalid assessment-type: '${assessment_type}'. Expected 1 or 2." >&2
  exit 2
fi

egress="${egress:-false}"
if [[ "${egress}" != "true" && "${egress}" != "false" ]]; then
  echo "Invalid egress: '${egress}'. Expected 'true' or 'false'." >&2
  exit 2
fi

upload="${upload:-auto}"
if [[ "${upload}" != "auto" && "${upload}" != "required" && "${upload}" != "off" ]]; then
  echo "Invalid upload: '${upload}'. Expected 'auto', 'required' or 'off'." >&2
  exit 2
fi

strict="${strict:-false}"
if [[ "${strict}" != "true" && "${strict}" != "false" ]]; then
  echo "Invalid strict: '${strict}'. Expected 'true' or 'false'." >&2
  exit 2
fi

workspace="${GITHUB_WORKSPACE:-/github/workspace}"
tfstate_path=""

if [[ -n "${tfstate}" ]]; then
  # Offline mode: the inventory is parsed from the state file, so no cloud
  # credentials are collected and auth-mode is not consulted.
  if [[ "${egress}" == "true" ]]; then
    echo "egress cannot be combined with tfstate: egress estimation requires live cloud API access." >&2
    exit 2
  fi

  if [[ "${tfstate}" = /* ]]; then
    tfstate_path="${tfstate}"
  else
    tfstate_path="${workspace}/${tfstate}"
  fi

  if [[ ! -f "${tfstate_path}" ]]; then
    echo "Terraform state file not found: ${tfstate_path}" >&2
    echo "  input 'tfstate' was '${tfstate}', resolved against ${workspace}" >&2
    exit 2
  fi

  echo "tfstate mode: reading ${tfstate_path}"
  echo "No cloud credentials are used; auth-mode is ignored."
else
  if [[ "${auth_mode}" != "static" && "${auth_mode}" != "oidc" ]]; then
    echo "Invalid auth-mode: '${auth_mode}'. Expected 'static' or 'oidc'." >&2
    exit 2
  fi
fi

# Built as an array so a workspace path containing spaces survives expansion.
cli_args=(--non-interactive --upload "${upload}")
if [[ -n "${tfstate_path}" ]]; then
  cli_args+=(--tfstate "${tfstate_path}")
fi
if [[ "${egress}" == "true" ]]; then
  cli_args+=(--egress)
fi
if [[ "${strict}" == "true" ]]; then
  cli_args+=(--strict)
fi

mkdir -p "${workspace}"
cd "${workspace}"

rm -rf cloudexit
git init -q cloudexit
cd cloudexit
git remote add origin https://github.com/escapecloud/cloudexit.git
git fetch --depth 1 origin "${cloudexit_ref}"
git checkout --detach -q FETCH_HEAD

python -m pip install --upgrade pip
pip install .

export ESC_EXIT_STRATEGY="${exit_strategy}"
export ESC_ASSESSMENT_TYPE="${assessment_type}"
if [[ -n "${input_host}" ]]; then
  export CLOUDEXIT_HOST="${input_host}"
fi
if [[ -n "${input_key}" ]]; then
  export CLOUDEXIT_API_KEY="${input_key}"
fi

cli_status=0

if [[ "${provider}" == "aws" ]]; then
  if [[ -z "${tfstate_path}" ]]; then
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
  fi
  python main.py aws "${cli_args[@]}" || cli_status=$?
fi

if [[ "${provider}" == "azure" ]]; then
  if [[ -z "${tfstate_path}" ]]; then
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
  fi

  python main.py azure "${cli_args[@]}" || cli_status=$?
fi

if [[ -d reports ]]; then
  # The CLI keeps reports owner-only and the container runs as root, so hand
  # them to the workspace owner for later steps such as upload-artifact.
  chown -R "$(stat -c '%u:%g' "${workspace}")" reports || true
fi

latest_report_dir="$(ls -1dt reports/* 2>/dev/null | head -n 1 || true)"
if [[ -n "${latest_report_dir:-}" && -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "report-dir=cloudexit/${latest_report_dir}" >> "${GITHUB_OUTPUT}"
fi

exit "${cli_status}"
