# Google Cloud Agent Identity Codelab (Enterprise 201)

This project contains a Jupyter Notebook that shows how to provision an **Agent Identity** on **Google Cloud's Agent Engine** before deploying ADK agent code to the engine and to assign permissions **before** deploying the agent code.

## Notebook Overview

The notebook is available both locally in your workspace:
👉 [agent_identity_codelab.ipynb](./agent_identity_codelab.ipynb)

And deployed directly in your Google Cloud Project:
* **GCS Bucket:** `gs://your-gcp-project-id-codelab`
* **Region:** `us-central1`
* **Objects:**
  * `gs://your-gcp-project-id-codelab/agent_identity_codelab.ipynb`
  * `gs://your-gcp-project-id-codelab/README.md`

The notebook provides an executable, step-by-step hands-on guide that:
1. **Resolves Project Metadata:** Programmatically fetches the numeric Project Number from the Google Cloud API.
2. **Creates an "Empty Shell" Agent Engine:** Programmatically provisions a lightweight, identity-only Agent Engine instance on Vertex AI without deploying any agent code to dynamically allocate the platform-assigned SPIFFE-based principal ID.
3. **Creates a Secret in Google Secret Manager:** Creates a secure credential placeholder in Secret Manager.
4. **Pre-Permissions the Identity:** Programmatically grants the allocated principal ID access (`roles/secretmanager.secretAccessor`) on the secret beforehand.
5. **Verifies Active Policies:** Fetches and verifies active IAM policy bindings to ensure zero-downtime, secure-by-default access from the first moment of deployment.
6. **Deploys Agent Code:** Deploys the ADK agent codebase to the pre-existing, pre-permissioned empty shell Agent Engine instance.
7. **(Optional) Live Deployment Verification:** Searches for a live deployed Secret Agent, constructs its identity, and authorizes it.


---

## Pre-requisites

To run the notebook successfully, ensure the following requirements are met:

### 1. Google Cloud CLI (`gcloud`)
The Google Cloud SDK must be installed on your local machine or run within a Google Cloud Shell.
* Check your installation by running:
  ```bash
  gcloud version
  ```

### 2. Google Cloud Permissions
Your authenticated `gcloud` identity must possess the following IAM roles on your target project:
* `roles/owner` or a combination of:
  * `roles/resourcemanager.projectIamAdmin` (to manage service account bindings)
  * `roles/secretmanager.admin` (to create secrets and manage their policies)
  * `roles/serviceusage.serviceUsageAdmin` (to enable APIs)

### 3. Enabled Services
The following APIs must be enabled in your target Google Cloud Project:
* Secret Manager API (`secretmanager.googleapis.com`)
* Vertex AI API (`aiplatform.googleapis.com`)

### 4. Python Environment
To isolate project dependencies, set up a virtual environment (using `uv` as recommended in the notebook, or standard `venv` as a fallback):

#### Option A: Using `uv` (Recommended)
```bash
# Initialize venv and install requirements via uv
uv venv && source .venv/bin/activate && uv pip install --keyring-provider subprocess -r requirements.txt
```

#### Option B: Using Standard Python `venv`
```bash
# Create and activate a standard virtual environment
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
```

### 5. Proof of Concept (PoC) Secret Agent Local Setup
This repository includes a minimal Google Agent Development Kit (ADK) agent under `secret_agent/` designed to connect to Secret Manager and retrieve a secret to prove successful permissioning.

To configure and run the local `secret_agent` using ADK:
1. **Configure Environment Variables:**
   Duplicate the provided example environment configuration file:
   ```bash
   cp secret_agent/.env.example secret_agent/.env
   ```
   Open `secret_agent/.env` and replace placeholders with your custom parameters:
   * `GOOGLE_GENAI_USE_ENTERPRISE=1` (Instructs ADK to use Vertex AI Enterprise Mode via Application Default Credentials)
   * `GOOGLE_CLOUD_PROJECT=your-gcp-project-id` (Your Google Cloud Project ID)
   * `GOOGLE_CLOUD_LOCATION=your-gcp-region` (The region for Vertex AI, e.g., `us-central1`)

2. **Install Agent Dependencies:**
   Ensure your Python virtual environment is activated, then install the agent's requirements:
   ```bash
   # Using uv (if using Option A)
   uv pip install -r secret_agent/requirements.txt

   # Using standard pip (if using Option B)
   pip install -r secret_agent/requirements.txt
   ```

3. **Run the Agent:**
   Start the interactive ADK session to chat with your secret agent:
   ```bash
   adk run secret_agent
   ```

### 6. Deploying the Agent to the Agent Engine (Gemini Enterprise Agent Platform)
#### Option A: Use the notebook agent_deployment.ipynb to create a new agent engine and deploy your agent code to it with the engine id created in that same notebook.

#### Option B: Deploy to a Pre-defined Agent Engine ID (Pre-permissioned Empty Shell)
To deploy your agent code to the **pre-defined (empty shell) Agent Engine ID** you created in Step 2:
```bash
# Pass the pre-defined agent ID as an argument
./deploy_agent.sh <your-predefined-agent-id>

# Alternatively, run without arguments and the script will list existing IDs to choose from
./deploy_agent.sh
```

---


## Technical Q&A: Agent Identity in Google Cloud's Agent Engine

### Q1: Is it possible to specify an existing identity?
* **Answer:** No. Google’s Agent Identity is designed to act as a cryptographically attested, SPIFFE-based identity that is intrinsically tied to the lifecycle and resource path of a specific agent. Because it is auto-provisioned by the platform (complete with a short-lived, auto-rotating X.509 certificate), you can't "bring your own" identity to the deployment.

### Q2: Is it possible to pre-create / pre-permission an identity?
* **Answer:** **Yes, via an "empty shell" deployment.** You cannot predict the SPIFFE ID entirely offline because the Agent Engine ID is a platform-assigned numeric identifier generated at resource creation. However, you can provision an empty Agent Engine instance (without any agent code) to allocate the identity beforehand. Once the identity is allocated, you can programmatically capture its SPIFFE ID, assign the necessary permissions, and then later deploy your real agent code to that pre-existing engine instance.

### Q3: Am I just approaching this problem wrong?
* **Answer:** Your approach is good. Pre-permissioning using an empty shell deployment to separate identity provisioning from code deployment is an industry-standard secure-by-default enterprise agent pattern. Create the agent engine beforehand to separate security setup from code deployment.

---

## Example Dialog

Below is an example of the dialog flow with the proof-of-concept Secret Manager Agent retrieving credentials using the pre-permissioned security context:

![Example Dialog](./media/BYm9XrRN6MPfeHV%20example%20dialog.png)

