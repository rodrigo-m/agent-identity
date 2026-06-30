import os
import vertexai
from vertexai import agent_engines
from vertexai import types

# Resolve Google Cloud Project ID dynamically
PROJECT_ID = os.environ.get("GOOGLE_CLOUD_PROJECT")
if not PROJECT_ID:
    import subprocess
    try:
        PROJECT_ID = subprocess.check_output(
            ["gcloud", "config", "get-value", "project"]
        ).decode("utf-8").strip()
    except Exception:
        PROJECT_ID = "your-gcp-project-id"

if not PROJECT_ID or PROJECT_ID == "(unset)":
    PROJECT_ID = "your-gcp-project-id"

LOCATION = os.environ.get("GOOGLE_CLOUD_LOCATION", "us-central1")

client = vertexai.Client(
  project=PROJECT_ID,
  location=LOCATION,
  http_options=dict(api_version="v1beta1")
)
remote_app = client.agent_engines.create(
  config={
    "display_name": "identity-for-agent",
    "identity_type": types.IdentityType.AGENT_IDENTITY,
  },
)

# Retrieve the newly created Agent Identity
effective_identity = remote_app.api_resource.spec.effective_identity
iam_principal = f"principal://{effective_identity}"

print("======================================================================")
print("Agent Identity Created Successfully!")
print("======================================================================")
print(f"SPIFFE ID:     {effective_identity}")
print(f"IAM Member ID: {iam_principal}")
print("======================================================================")