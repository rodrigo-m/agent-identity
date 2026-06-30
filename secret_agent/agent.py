import os
import google.auth
from google.adk.agents.llm_agent import Agent
from google.cloud import secretmanager

def get_current_principal() -> str:
    """Helper to detect the current GCP principal/identity."""
    # 1. Try metadata server (GCP managed environments)
    import urllib.request
    try:
        req = urllib.request.Request(
            "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/email"
        )
        req.add_header("Metadata-Flavor", "Google")
        with urllib.request.urlopen(req, timeout=1) as response:
            email = response.read().decode("utf-8").strip()
            if email:
                return f"serviceAccount:{email}"
    except Exception:
        pass

    # 2. Try google.auth credentials
    try:
        credentials, _ = google.auth.default()
        if hasattr(credentials, "service_account_email") and credentials.service_account_email:
            return f"serviceAccount:{credentials.service_account_email}"
        if hasattr(credentials, "signer_email") and credentials.signer_email:
            return f"serviceAccount:{credentials.signer_email}"
    except Exception:
        pass

    # 3. Fallback to local environment user
    user_env = os.environ.get("USER") or os.environ.get("USERNAME") or "Developer"
    return f"user:{user_env} (Local ADC)"

def get_secret(secret_id: str, version_id: str = "latest") -> str:
    """Retrieves the value of a secret from Google Cloud Secret Manager.

    Args:
        secret_id: The ID/name of the secret to retrieve.
        version_id: The version of the secret (defaults to 'latest').
    """
    project_id = os.environ.get("GOOGLE_CLOUD_PROJECT", "your-gcp-project-id")
    client = secretmanager.SecretManagerServiceClient()
    name = f"projects/{project_id}/secrets/{secret_id}/versions/{version_id}"
    
    principal = get_current_principal()
    print(f"==============================================================")
    print(f"[SECURITY CONTEXT] Accessing Secret Manager under identity:")
    print(f" -> {principal}")
    print(f"==============================================================")
    
    try:
        response = client.access_secret_version(request={"name": name})
        secret_value = response.payload.data.decode("UTF-8")
        return f"[Principal: {principal}] Secret Value: {secret_value}"
    except Exception as e:
        return f"[Principal: {principal}] Error retrieving secret: {str(e)}"

system_instruction = """
You are a proof-of-concept security agent. When asked to retrieve
a secret, use the get_secret tool. In your response, explicitly report
the security context/principal identity you ran under, output 'I have the secret',
and print the secret value exactly.
"""

root_agent = Agent(
    model='gemini-2.5-flash',
    name='secret_agent',
    description='Retrieves a secret from Google Cloud Secret Manager.',
    instruction=system_instruction,
    tools=[get_secret],
)
