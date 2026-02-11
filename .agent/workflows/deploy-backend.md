---
description: Build and deploy the news-scraper as a Docker container for VDS
---

This workflow will build and run the news-scraper using Docker.

### Prerequisites
1. Ensure you have **Docker** and **Docker Compose** installed on your VDS.
2. Ensure port **3000** is open in your VDS firewall.

### Deployment Steps

1. Navigate to the project directory:
```powershell
cd backend/news-scraper
```

2. Build and start the container in detached mode:
// turbo
```powershell
docker compose up -d --build
```

3. Check the logs to ensure it's scraping:
```powershell
docker compose logs -f
```

4. Verify the API is working:
Visit `http://your-vds-ip:3000/news` in your browser.

