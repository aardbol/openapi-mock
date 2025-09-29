# Infrastructure as Code (IaC) Deployment Guide

This repository contains Infrastructure as Code (IaC) resources organized into two main categories:

- **`iac`** - Infrastructure components (deployed manually)
  - **`opentofu/`** - AWS infrastructure using OpenTofu
  - **`kustomize/`** - Kubernetes resources using Kustomize
    - **`apps/`** - Application deployments (deployed via GitHub Actions)
    - **`infra/`** - Infrastructure deployments (deployed manually)
## 📋 Prerequisites

Before deploying any resources, ensure you have:

- [ ] AWS CLI configured with appropriate credentials
- [ ] OpenTofu installed (version 1.10+)
- [ ] Latest kubectl configured to access your Kubernetes cluster
- [ ] Appropriate IAM permissions for resource creation

## 🏗️ Infrastructure Deployment (Manual)

### AWS Infrastructure (OpenTofu)

The `iac/opentofu` folder contains AWS infrastructure components that must be deployed manually.

#### OpenTofu Deployment Steps

1. **Navigate to the OpenTofu directory:**
   ```bash
   cd iac/opentofu
   ```

2. **Initialize OpenTofu for the first time:**
   ```bash
   tofu init
   ```

3. **Create execution plan:**
   ```bash
   tofu plan -out tfplan
   ```

4. **Apply the planned changes:**
   ```bash
   tofu apply tfplan
   ```

### Kubernetes Infrastructure using Kustomize (Manual)

The `iac/kustomize/infra` folder contains Kubernetes infrastructure components deployed using Kustomize.

#### Kustomize Deployment Steps

1. **Navigate to the Kustomize directory:**
   ```bash
   cd iac/kustomize/infra
   ```

2. **Preview the resources:**
   ```bash
   kustomize build . | kubectl diff -f -
   ```

3. **Apply the resources:**
   ```bash
   kubectl apply -k .
   ```

### Important Notes

- ⚠️ Infrastructure changes should be reviewed carefully before applying
- 🔒 Always run `tofu plan -out tfplan` first to understand what will be changed
- 📁 Plan files (`tfplan`) should not be committed to version control

## 🚀 Application Deployment (Automated)

The `iac/kustomize/apps` folder contains application-specific Kubernetes manifests and Kustomize configurations that are automatically deployed via GitHub Actions.

### Automated Deployment Process

1. **Trigger:** Deployments are triggered automatically when:
   - **Testing Environment:** Pull requests are created or updated
   - **Production Environment:** Changes are pushed to the main branch
   - **Manual Deployment:** Workflow dispatch is initiated for either environment

2. **Workflow:** The GitHub Action workflow will:
   - Build container images using Buildah and push to GitHub Container Registry (GHCR)
   - Set up kubectl with the appropriate kubeconfig
   - Create image pull secrets for GHCR access
   - Update Kustomize image tags with the new container image
   - Apply Kustomize manifests to the target Kubernetes cluster
   - Verify deployment success

3. **Environments:** Applications are deployed to:
   - **Testing:** Triggered by pull requests (uses `testing` environment and `KUBECONFIG_TESTING` secret)
   - **Production:** Triggered by main branch pushes (uses `prod` environment and `KUBECONFIG_PRODUCTION` secret)

### Container Image Management

- Images are built with tags: `{environment}-latest` and `{environment}-{commit_sha}`
- Images are stored in GitHub Container Registry: `ghcr.io/{repository_owner}/openapi-mock`
- Dependabot pull requests are automatically excluded from build and deployment
