Family Quest Character Creator Backend

This folder contains the AI character generation backend for the Family Quest Character Creator.

Setup

1. Install Python 3.10 or newer.
2. Install dependencies using "pip install -r requirements.txt".
3. Set the "TRIPO_API_KEY" environment variable securely.
4. Start the server using "uvicorn app:app --host 0.0.0.0 --port 8000".

Never store API keys in the Android app or public GitHub repository.

Important

The backend must be deployed to a server before the Android app can generate AI models.
