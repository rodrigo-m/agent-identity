import os
import google.auth
from google.adk.agents.llm_agent import Agent
from google.cloud import secretmanager

def get_current_principal() -> str:
    """Helper to detect the current GCP principal/identity."""
    import urllib.request
    import base64
    import json

    # 1. Try to fetch Identity Token from metadata server to detect Agent Identity (SPIFFE)
    try:
        # Request an identity token for the default service account with an arbitrary audience
        url = "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/identity?audience=https://aiplatform.googleapis.com/"
        req = urllib.request.Request(url)
        req.add_header("Metadata-Flavor", "Google")
        with urllib.request.urlopen(req, timeout=1) as response:
            token = response.read().decode("utf-8").strip()
            if token:
                parts = token.split('.')
                if len(parts) == 3:
                    # Decode the JWT payload (the second part)
                    payload_b64 = parts[1]
                    # Add padding if required by base64
                    payload_b64 += '=' * (4 - len(payload_b64) % 4)
                    payload_json = base64.urlsafe_b64decode(payload_b64).decode('utf-8')
                    payload = json.loads(payload_json)
                    sub = payload.get("sub")
                    if sub and sub.startswith("spiffe://"):
                        return sub.replace("spiffe://", "principal://")
    except Exception:
        pass

    # 2. Try metadata server service account email (standard GCP managed environments)
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

    # 2. Try google.auth credentials (service accounts / keys / high-fidelity user ADC)
    try:
        credentials, _ = google.auth.default()
        if hasattr(credentials, "service_account_email") and credentials.service_account_email:
            return f"serviceAccount:{credentials.service_account_email}"
        if hasattr(credentials, "signer_email") and credentials.signer_email:
            return f"serviceAccount:{credentials.signer_email}"
        
        # If it is a user/interactive credential, try to retrieve the email using Tokeninfo
        from google.auth.transport.requests import Request
        import ssl
        import json
        credentials.refresh(Request())
        if credentials.token:
            url = f"https://oauth2.googleapis.com/tokeninfo?access_token={credentials.token}"
            context = ssl._create_unverified_context()
            req = urllib.request.Request(url)
            with urllib.request.urlopen(req, context=context, timeout=2) as response:
                info = json.loads(response.read().decode("utf-8"))
                email = info.get("email")
                if email:
                    return f"user:{email} (Local ADC)"
    except Exception:
        pass

    # 3. Try to query active gcloud account as a local fallback
    import subprocess
    try:
        gcloud_account = subprocess.check_output(
            ["gcloud", "config", "get-value", "account"],
            stderr=subprocess.DEVNULL
        ).decode("utf-8").strip()
        if gcloud_account and gcloud_account != "(unset)":
            return f"user:{gcloud_account} (Local ADC)"
    except Exception:
        pass

    # 4. Fallback to OS-level user context
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
