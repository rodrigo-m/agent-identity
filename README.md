# Google Cloud Agent Identity Codelab (Enterprise 201)

This project contains a Jupyter Notebook designed to accompany the 201 learning path, demonstrating the predictability, pre-creation, and pre-permissioning of cryptographically attested, SPIFFE-based Agent Identities on Google Cloud's Agent Engine.

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
1. **Resolves Project Metadata:** Programmatically fetches the numeric Project Number and Organization ID from the Google Cloud API.
2. **Derives Predictable SPIFFE Principal ID:** Demonstrates how Google Cloud Agent Identity principal IDs are deterministic.
3. **Demonstrates Pre-permissioning:** Creates a secure credential placeholder in Secret Manager and programmatically grants the predicted principal ID access (`roles/secretmanager.secretAccessor`).
4. **Verifies Active Policies:** Fetches and verifies active IAM policy bindings to ensure zero-downtime, secure-by-default access from the first moment of deployment.
5. **Creates an Engine Without Agent Code:** Programmatically provisions an Agent Identity on Vertex AI without deploying any agent code, retrieves the resulting identity, and shows that it matches our SPIFFE predictions exactly!
6. **(Optional) Verifies Live Deployments:** Searches for a live deployed Secret Agent, constructs its identity, and authorizes it.


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
The local python environment must be initialized and package dependencies installed from the root `requirements.txt`:
```bash
python3 -m venv venv
source venv/bin/activate
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

2. **Install ADK and Agent Dependencies:**
   Ensure your Python virtual environment is activated, then install `google-adk` and the agent's requirements:
   ```bash
   pip install google-adk
   pip install -r secret_agent/requirements.txt
   ```

3. **Run the Agent:**
   Start the interactive ADK session to chat with your secret agent:
   ```bash
   adk run secret_agent
   ```

---

## Technical Q&A: Agent Identity in Google Cloud's Agent Engine

### Q1: Is it possible to specify an existing identity?
* **Answer:** No. Google’s Agent Identity is designed to act as a cryptographically attested, SPIFFE-based identity that is intrinsically tied to the lifecycle and resource path of a specific agent. Because it is auto-provisioned by the platform (complete with a short-lived, auto-rotating X.509 certificate), you can't "bring your own" identity to the deployment.

### Q2: Is it possible to pre-create / pre-permission an identity?
* **Answer:** **Yes!** You don't have to wait until after deployment to assign permissions. You can create an agent engine instance with the associated identity and retrieve the principal id associated with it. The python sample code demonstrates this by creating an agent instance using the vertexai python sdk, it then retrieves the principal id associated with the agent instance and prints it, at which point you can pre-permission it for whatever resources it might need access to. When deploying the real agent code use the engine id in the deployment command to deploy it to the right agent engine. 

### Q3: Am I just approaching this problem wrong?
* **Answer:** Your approach is good. Pre-permissioning using the predictable SPIFFE-based principal ID string is a pattern for zero-downtime, secure-by-default enterprise agent setups. There is an argument for retrieving the SPIFFE id string after the first agent deployment instead, since you will have to wait for IAM propagation anyways, but creating the agent engine before code deployment separates the concerns (i.e. security setup vs code deployment).

---

## Example Dialog

Below is an example of the dialog flow with the proof-of-concept Secret Manager Agent retrieving credentials using the pre-permissioned security context:

![Example Dialog](./media/BYm9XrRN6MPfeHV%20example%20dialog.png)

