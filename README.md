# cloudexit-action

Run [cloudexit](https://github.com/escapecloud/cloudexit) in GitHub Actions using non-interactive mode.

## Inputs

| Name | Required | Default | Description |
|---|---|---|---|
| `provider` | Yes | — | Cloud provider: `aws` or `azure` |
| `auth-mode` | No | `static` | Authentication mode (v1 supports `static` only) |
| `exit-strategy` | Yes | — | Exit strategy: `1` or `3` |
| `assessment-type` | Yes | — | Assessment type: `1` or `2` |
| `version` | No | `v1.0.8` | cloudexit version tag to checkout |
| `host` | No | `""` | Passed as `HOST`; empty keeps offline mode |
| `key` | No | `""` | Passed as `KEY`; empty keeps offline mode |

## Required environment variables

### AWS runs

| Variable | Required | Description |
|---|---|---|
| `AWS_ACCESS_KEY_ID` | Yes | AWS access key id |
| `AWS_SECRET_ACCESS_KEY` | Yes | AWS secret access key |
| `AWS_DEFAULT_REGION` (or `AWS_REGION`) | Yes | AWS region |

### Azure runs

| Variable | Required | Description |
|---|---|---|
| `AZURE_TENANT_ID` | Yes | Azure tenant id |
| `AZURE_CLIENT_ID` | Yes | Azure client/application id |
| `AZURE_CLIENT_SECRET` | Yes | Azure client secret |
| `ESC_SUBSCRIPTION_ID` | Yes | Azure subscription id used by cloudexit |
| `ESC_RESOURCE_GROUP` | Yes | Azure resource group used by cloudexit |

## Output

- `report-dir`: latest generated report directory path (for example `cloudexit/reports/20260614123456`)

## Usage

### AWS with static credentials

```yaml
name: CloudExit AWS Static
on:
  workflow_dispatch:

jobs:
  run:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - name: Run cloudexit
        uses: escapecloud/cloudexit-action@v0
        with:
          provider: aws
          auth-mode: static
          exit-strategy: "1"
          assessment-type: "1"
          host: ""
          key: ""
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          AWS_DEFAULT_REGION: ${{ vars.AWS_DEFAULT_REGION }}

      - name: Upload reports
        uses: actions/upload-artifact@v4
        with:
          name: reports-aws
          path: cloudexit/reports/**
```


### Azure with static credentials

```yaml
name: CloudExit Azure Static
on:
  workflow_dispatch:

jobs:
  run:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - name: Run cloudexit
        uses: escapecloud/cloudexit-action@v0
        with:
          provider: azure
          auth-mode: static
          exit-strategy: "1"
          assessment-type: "1"
          host: ""
          key: ""
        env:
          AZURE_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
          AZURE_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
          AZURE_CLIENT_SECRET: ${{ secrets.AZURE_CLIENT_SECRET }}
          ESC_SUBSCRIPTION_ID: ${{ vars.AZURE_SUBSCRIPTION_ID }}
          ESC_RESOURCE_GROUP: ${{ vars.AZURE_RESOURCE_GROUP }}
```

## Notes

This initial version supports only static credentials configured as GitHub repository secrets. OIDC support will be added in a later release.
