# Hello! 👋

This is the official GitHub Action for [cloudexit](https://github.com/escapecloud/cloudexit), built by EscapeCloud to run automated cloud exit readiness assessments in CI/CD.

It supports both static credentials and short-lived OIDC authentication for AWS and Azure.

## Inputs

| Name | Required | Default | Description |
|---|---|---|---|
| `provider` | Yes | — | Cloud provider: `aws` or `azure` |
| `auth-mode` | No | `static` | Authentication mode: `static` or `oidc` |
| `exit-strategy` | Yes | — | Exit strategy: `1` or `3` |
| `assessment-type` | Yes | — | Assessment type: `1` or `2` |
| `version` | No | `v1.1.1` | cloudexit version tag to checkout |
| `host` | No | `""` | Passed as `HOST`; empty keeps offline mode |
| `key` | No | `""` | Passed as `KEY`; empty keeps offline mode |

## Output

- `report-dir`: latest generated report directory path (for example `cloudexit/reports/20260614123456`)

## Quick usage

### Static mode (example)

```yaml
- name: Run cloudexit
  uses: escapecloud/cloudexit-actions@v1
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

  - uses: escapecloud/cloudexit-actions@v1
    with:
      provider: aws
      auth-mode: oidc
      exit-strategy: "1"
      assessment-type: "1"
    env:
      AWS_DEFAULT_REGION: ${{ vars.AWS_DEFAULT_REGION }}
```

## Full documentation

For complete setup guides (AWS/Azure, static/OIDC, troubleshooting), see:

- [Overview](https://cloudexit.escapecloud.io/non-interactive/overview.html)
- [AWS guide](https://cloudexit.escapecloud.io/non-interactive/aws.html)
- [Azure guide](https://cloudexit.escapecloud.io/non-interactive/azure.html)
- [GitHub Actions guide](https://cloudexit.escapecloud.io/non-interactive/github-actions.html)

## Notes

OIDC mode expects credentials to be prepared by a prior login step (`aws-actions/configure-aws-credentials` for AWS, `azure/login` for Azure). Static mode continues to support long-lived credentials.
