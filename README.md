# Shell-Roboshop 🛒

Automated deployment of the **Roboshop** e-commerce microservices application using Shell scripts — each service independently configured and deployed on Linux (AWS EC2).

> This is the **manual scripting version** of Roboshop.  
> After completing this, the same application was containerised using Docker → [see Roboshop on Docker](https://github.com/Kaladhars-Hub/roboshop-docker)

---

## 💡 Why build it with Shell scripts first?

Before containerising an application with Docker, you need to understand what is actually happening inside each service — what gets installed, how services connect, what order they start in, and what breaks when something is missing.

This project is that foundation. Every step that Docker automates was done manually here first.

```
Shell scripts  →  understand every step manually
      ↓
Docker         →  containerise what you now understand
      ↓
Kubernetes     →  orchestrate at scale (coming next)
```

---

## 🏗️ Architecture

| Service | Technology | Depends On |
|---|---|---|
| frontend | Nginx | all services |
| catalogue | Node.js | MongoDB |
| user | Node.js | MongoDB + Redis |
| cart | Node.js | Redis + Catalogue |
| shipping | Java | MySQL + Cart |
| payment | Python | RabbitMQ + Cart + User |
| dispatch | Go | RabbitMQ |
| mongodb | MongoDB | — |
| redis | Redis | — |
| mysql | MySQL | — |
| rabbitmq | RabbitMQ | — |

> Deployment order matters — databases must be running before the services that depend on them.

---

## 🎯 What each script does

Every service has a dedicated Shell script that:

- Installs required dependencies and runtimes
- Creates a dedicated system user for the service
- Downloads and configures the application
- Sets up and starts a `systemd` service
- Includes error handling — script exits immediately if any step fails
- Logs status at each step so you can see exactly where a failure happens

---

## 🚀 How to run

> ⚠️ Designed for RHEL/CentOS based Linux. Tested on AWS EC2 (RHEL 9). Run as root or with sudo.

```bash
git clone https://github.com/Kaladhars-Hub/Shell-Roboshop.git
cd Shell-Roboshop

# Always start with databases first
chmod +x mongodb.sh && ./mongodb.sh
chmod +x redis.sh   && ./redis.sh
chmod +x mysql.sh   && ./mysql.sh
chmod +x rabbitmq.sh && ./rabbitmq.sh

# Then application services
chmod +x catalogue.sh && ./catalogue.sh
chmod +x user.sh      && ./user.sh
chmod +x cart.sh      && ./cart.sh
chmod +x shipping.sh  && ./shipping.sh
chmod +x payment.sh   && ./payment.sh
chmod +x dispatch.sh  && ./dispatch.sh

# Frontend last
chmod +x frontend.sh && ./frontend.sh
```

---

## 🛠️ Tech used

| Category | Tools |
|---|---|
| Scripting | Bash / Shell |
| Cloud | AWS EC2 |
| OS | Linux — RHEL 9 |
| Init System | systemd |
| Databases | MongoDB, MySQL, Redis, RabbitMQ |
| Runtimes | Node.js, Java, Python, Go, nginx |

---

## 📚 Key learnings

- Deploying services manually builds the foundation for understanding what Docker, Ansible, and Kubernetes automate. You cannot fully appreciate containerisation without first doing it the hard way.
- Learned `systemd` service management — creating unit files, enabling services on boot, checking status and logs with `journalctl`.
- Understood **inter-service dependencies** — what actually breaks when MongoDB is not ready before Catalogue starts.
- Hands-on with Linux package managers (`yum` / `dnf`), file permissions, system users, and directory structure.

---

## 🔗 Related project

This project and the Docker version below are the same application deployed two different ways:

| | [Shell Roboshop](https://github.com/Kaladhars-Hub/Shell-Roboshop) | [Docker Roboshop](https://github.com/Kaladhars-Hub/roboshop-docker) |
|---|---|---|
| Approach | Manual — one script per service | Containerised — Docker Compose |
| Setup time | ~45 minutes (run all scripts) | ~2 minutes (`docker compose up -d`) |
| Runs on | Bare Linux (any RHEL server) | Any machine with Docker |
| Data persistence | Files on disk | Named Docker volumes |
| Service discovery | Hardcoded IPs | DNS by container name |
| Startup order | Manual (run in right order) | Automatic (`depends_on`) |

---

## 👤 Author

**Kaladhar** · [GitHub](https://github.com/Kaladhars-Hub) · [LinkedIn](https://www.linkedin.com/in/kaladharknights/)

> Built as part of a hands-on DevOps learning journey.
