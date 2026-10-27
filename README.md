# Hello! 👋

This is the official GitHub Action for [cloudexit](https://github.com/escapecloud/cloudexit), built by EscapeCloud to run automated cloud exit readiness assessments in CI/CD.

It supports both static credentials and short-lived OIDC authentication for AWS and Azure.

## Inputs

| Name | Required | Default | Description |
|---|---|---|---|
| `provider` | Yes | — | Cloud provider: `aws` or `azure` |
| `auth-mode` | No | `static` | Authentication mode: `static` or `oidc` |
| `exit-strategy` | Yes | — | Exit strategy: `1`, `2` or `3` |
| `assessment-type` | Yes | — | Assessment type: `1` or `2` (`2` needs a platform upload; offline runs produce the Basic assessment) |
| `egress` | No | `false` | Estimate egress: `true` or `false` |
| `tfstate` | No | `""` | Path to a Terraform/OpenTofu state file, relative to the workspace |
| `version` | No | `v2.0.0` | cloudexit version tag to checkout |
| `host` | No | `""` | Platform host, passed as `CLOUDEXIT_HOST`; empty (with `key`) keeps offline mode |
| `key` | No | `""` | Platform API key, passed as `CLOUDEXIT_API_KEY`; empty (with `host`) keeps offline mode |
| `upload` | No | `auto` | Upload mode: `auto` (upload when `host` and `key` are set, otherwise offline), `required` (fail when they are not set) or `off` (never upload) |
| `strict` | No | `false` | Fail the run when the platform reports warnings: `true` or `false` |

## Output

- `report-dir`: latest generated report directory path (for example `cloudexit/reports/20260614123456-a1b2c3d4`)

## Quick usage

### Static mode (example)

```yaml
- name: Run cloudexit
  uses: escapecloud/cloudexit-actions@v2
  with:
    provider: aws
    auth-mode: static
    exit-strategy: "1"
    assessment-type: "1"
  env:
    AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
    AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    AWS_DEFAULT_REGION: ${{ vars.AWS_DEFAULT_REGION }}
```

### OIDC mode (example)

```yaml
permissions:
  id-token: write
  contents: read

steps:
  - uses: aws-actions/configure-aws-credentials@v4
    with:
      role-to-assume: ${{ secrets.AWS_ROLE_TO_ASSUME }}
      aws-region: ${{ vars.AWS_DEFAULT_REGION }}

  - uses: escapecloud/cloudexit-actions@v2
    with:
      provider: aws
      auth-mode: oidc
      exit-strategy: "1"
      assessment-type: "1"
    env:
      AWS_DEFAULT_REGION: ${{ vars.AWS_DEFAULT_REGION }}
```

### Terraform / OpenTofu state file (example)

```yaml
- uses: hashicorp/setup-terraform@v3
- run: terraform init
- run: terraform state pull > infra.tfstate

- uses: escapecloud/cloudexit-actions@v2
  with:
    provider: aws
    tfstate: infra.tfstate
    exit-strategy: "1"
    assessment-type: "1"
```

### Platform upload (example)

```yaml
- uses: escapecloud/cloudexit-actions@v2
  with:
    provider: aws
    exit-strategy: "1"
    assessment-type: "1"
    upload: required
    host: ${{ vars.CLOUDEXIT_HOST }}
    key: ${{ secrets.CLOUDEXIT_API_KEY }}
  env:
    AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
    AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    AWS_DEFAULT_REGION: ${{ vars.AWS_DEFAULT_REGION }}
```

Set both `host` and `key`, or neither: with only one of them the run fails with a configuration error. With `upload: required` the run fails before collecting anything when they are empty. A failed upload still writes the reports and sets `report-dir`; the step then fails with an upload exit code (10–15).

## Full documentation

For complete setup guides (AWS/Azure, static/OIDC, troubleshooting), see:

- [Overview](https://cloudexit.escapecloud.io/non-interactive/overview.html)
- [AWS guide](https://cloudexit.escapecloud.io/non-interactive/aws.html)
- [Azure guide](https://cloudexit.escapecloud.io/non-interactive/azure.html)
- [GitHub Actions guide](https://cloudexit.escapecloud.io/non-interactive/github-actions.html)

## Notes

OIDC mode expects credentials to be prepared by a prior login step (`aws-actions/configure-aws-credentials` for AWS, `azure/login` for Azure). Static mode continues to support long-lived credentials.
