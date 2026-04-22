# Security Audit & Hardening Recommendations: Lambda Container Image

This document outlines the findings from a security audit of the Lambda container image and provides actionable recommendations to harden its security posture.

## 1. Executive Summary
The Lambda container image is based on `amazonlinux:2023`. While it follows several best practices (e.g., non-root user, no shell injection), it currently carries several HIGH-severity vulnerabilities in its base packages and lacks strict dependency pinning.

## 2. Key Findings

| ID | Severity | Category | Finding | Recommendation |
| :--- | :--- | :--- | :--- | :--- |
| **SEC-01** | High | Vulnerability | The base image `amazonlinux:2023` contains 15 HIGH vulnerabilities in core libraries (`openssl`, `python3`, `libnghttp2`). | Add `dnf upgrade -y` to the Dockerfile to ensure all system packages are patched during the build process. |
| **SEC-02** | Low | Supply Chain | System packages (`createrepo_c`, `python3`) and Python packages (`awslambdaric`) are not pinned to specific versions. | Pin all dependencies to specific versions (e.g., `awslambdaric==4.0.0`) to ensure build reproducibility and prevent unexpected updates. |
| **SEC-03** | Low | Image Bloat | `pip install` does not use the `--no-cache-dir` flag, increasing image size and leaving unnecessary files in the image layers. | Use `--no-cache-dir` in all `pip install` commands. |
| **SEC-04** | Info | Hardcoding | The repository directory `/mnt/repo` is hardcoded in the Python script. | Use an environment variable (e.g., `REPO_PATH`) to configure the mount path, improving modularity. |
| **SEC-05** | Info | Observability | The script logs the full output of `createrepo_c`. | Ensure that repository metadata logged does not contain sensitive paths or internal information. |

## 3. Automated Scan Detailed Results

### Hadolint (Dockerfile Linter)
*   **DL3041 (Warning):** Specify version with `dnf install -y <package>-<version>`.
*   **DL3013 (Warning):** Pin versions in pip.
*   **DL3042 (Warning):** Avoid use of cache directory with pip.

### Bandit (Python Security Scanner)
*   **B404/B603 (Low):** Use of `subprocess`.
    *   *Status:* Mitigated. The implementation uses a list-based command (`subprocess.run(["cmd", "arg"])`) which avoids shell execution, significantly reducing injection risk.

### Trivy (Vulnerability Scanner)
*   **Target:** `amazonlinux:2023`
*   **Summary:** 15 HIGH vulnerabilities detected.
*   **Primary Culprits:** `openssl-libs`, `python3`, `libnghttp2`.
*   **Remediation:** All identified vulnerabilities have fixes available in newer versions of the Amazon Linux 2023 repositories.

## 4. Proposed Hardened Dockerfile

```dockerfile
# Use Amazon Linux 2023 as the base image
FROM amazonlinux:2023

# Update system and install dependencies
# - dnf upgrade: patches known vulnerabilities in the base image
# - createrepo_c: pinned for reproducibility
RUN dnf upgrade -y && \
    dnf install -y \
    createrepo_c-0.20.0-1.amzn2023.0.3 \
    python3-3.9.25-1.amzn2023.0.4 \
    python3-pip \
    && dnf clean all

# Set the working directory
WORKDIR /var/task

# Install RIC with pinning and without cache
RUN pip3 install --no-cache-dir awslambdaric==4.0.0

# Create a non-root user
RUN groupadd -g 1001 lambdauser && \
    useradd -u 1001 -g lambdauser -s /bin/sh lambdauser

# Copy script and set ownership
COPY index.py .
RUN chown -R lambdauser:lambdauser /var/task

USER lambdauser

ENTRYPOINT [ "/usr/bin/python3", "-m", "awslambdaric" ]
CMD [ "index.handler" ]
```
