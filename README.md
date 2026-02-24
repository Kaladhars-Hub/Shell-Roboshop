# Shell-Roboshop 🛒

Automated deployment of the **Roboshop** e-commerce microservices application using Shell scripts — each service independently configured and deployed on Linux servers.

## 🏗️ About Roboshop

Roboshop is a real-world inspired, multi-tier e-commerce application with the following microservices:

| Service | Technology |
|---|---|
| Web | Nginx |
| Cart | Node.js |
| Catalogue | Node.js + MongoDB |
| User | Node.js + MongoDB |
| Payment | Python |
| Shipping | Java |
| Dispatch | Go |
| Databases | MongoDB, MySQL, Redis, RabbitMQ |

## 🎯 What This Project Does

Each microservice has a dedicated Shell script that:
- Installs required dependencies and runtimes
- Creates system users and directories
- Downloads and configures the service
- Sets up and starts `systemd` services
- Includes basic error handling and status logging

## 🛠️ Tech Used

- **Scripting:** Bash / Shell
- **OS:** Linux (RHEL/CentOS based)
- **Init System:** systemd
- **Databases:** MongoDB, MySQL, Redis, RabbitMQ

## 🚀 How to Use

```bash
git clone https://github.com/Kaladhars-Hub/Shell-Roboshop.git
cd Shell-Roboshop

# Run the script for the service you want to deploy
chmod +x mongodb.sh
./mongodb.sh
```

> ⚠️ Scripts are designed for RHEL/CentOS based Linux systems. Run as root or with sudo.

## 💡 Key Learnings

- Deploying multi-tier applications manually builds a strong foundation for understanding what tools like Ansible, Kubernetes, and CI/CD pipelines automate at scale.
- Hands-on exposure to systemd service management, package managers (`yum`/`dnf`), and inter-service dependencies.
