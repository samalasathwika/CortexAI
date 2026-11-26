import uvicorn
import os
from pathlib import Path

if __name__ == "__main__":
    port = int(os.getenv("PORT", 8000))
    host = os.getenv("HOST", "127.0.0.1")
    backend_dir = str(Path(__file__).resolve().parent)
    print(f"Starting Cortex AI server at http://{host}:{port}")
    uvicorn.run("app.main:app", host=host, port=port, reload=True, reload_dirs=[backend_dir])
