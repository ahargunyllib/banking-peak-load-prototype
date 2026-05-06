# Terraform — Banking Peak Load (AWS Staging)

Deploy seluruh stack ke AWS dengan satu command.

## Services yang dibuat

| Service | AWS Resource | Spec (staging) |
|---------|-------------|----------------|
| API Server | EC2 t3.medium | 2 vCPU, 4GB RAM |
| PostgreSQL Primary + Replica | RDS db.t3.micro | PostgreSQL 16 |
| Redis Cache | ElastiCache cache.t3.micro | Redis 7 |
| Load Balancer | ALB | HTTP:80 → EC2:8080 |
| Docker Registry | ECR | Auto cleanup >5 images |
| Network | VPC existing | Pakai VPC default VOCLabs |

> ⚠️ Amazon MQ (RabbitMQ) tidak tersedia di VOCLabs — di-skip untuk cloud deployment.

## Keterbatasan VOCLabs

| Service | Status | Alasan |
|---------|--------|--------|
| `iam:CreateRole` | ❌ Blocked | Pakai `LabInstanceProfile` yang sudah ada |
| Amazon MQ | ❌ Blocked | Service tidak tersedia di VOCLabs |
| `ec2:DescribeImages` | ❌ Blocked | AMI ID di-hardcode manual |
| EC2, RDS, ElastiCache, ALB, ECR | ✅ OK | Bisa dipakai normal |

## Prerequisites

```bash
# Install Terraform
wget https://releases.hashicorp.com/terraform/1.6.6/terraform_1.6.6_linux_amd64.zip
unzip terraform_1.6.6_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

## Setup Credentials VOCLabs (tiap Start Lab baru)

Buat script biar ga repot:
```bash
nano ~/update-creds.sh
```

Isi:
```bash
#!/bin/bash
AWS_ACCESS_KEY_ID="ASIA..."        # ganti tiap sesi
AWS_SECRET_ACCESS_KEY="xxx..."     # ganti tiap sesi
AWS_SESSION_TOKEN="xxx..."         # ganti tiap sesi (panjang banget)

aws configure set aws_access_key_id $AWS_ACCESS_KEY_ID
aws configure set aws_secret_access_key $AWS_SECRET_ACCESS_KEY
aws configure set aws_session_token $AWS_SESSION_TOKEN
aws configure set region us-east-1

echo "✅ Credentials updated!"
aws sts get-caller-identity
```

```bash
chmod +x ~/update-creds.sh
source ~/update-creds.sh
```

## Urutan Deploy yang Benar

> ⚠️ **PENTING:** Push Docker image ke ECR **DULU** sebelum EC2 dibuat.
> Kalau EC2 jalan sebelum image ada di ECR, container tidak akan otomatis jalan.

```bash
# 1. Masuk ke folder staging
cd terraform/environments/staging

# 2. Set password (DB min 8 karakter, MQ min 12 karakter)
export TF_VAR_db_password="PasswordKuat123!"
export TF_VAR_mq_password="PasswordKuat123!!!"

# 3. Init
terraform init

# 4. Buat ECR dulu (tanpa EC2)
terraform apply -target=module.ecr

# 5. Push Docker image ke ECR SEBELUM apply penuh
ECR_URL=$(terraform output -raw ecr_repository_url)
cd ../../..  # balik ke root project

aws ecr get-login-password --region us-east-1 \
  | docker login --username AWS --password-stdin $ECR_URL

docker build -f deployments/docker/Dockerfile -t $ECR_URL:latest .
docker push $ECR_URL:latest

# 6. Deploy semua termasuk EC2
cd terraform/environments/staging
terraform apply
```

## Kalau EC2 Sudah Terlanjur Jalan Sebelum Image di-push

Masuk via **EC2 Instance Connect** di AWS Console:
1. Buka https://console.aws.amazon.com/ec2
2. Pilih instance → **Connect** → **EC2 Instance Connect** → **Connect**

Lalu jalankan:
```bash
aws ecr get-login-password --region us-east-1 \
  | docker login --username AWS --password-stdin <ECR_URL>

docker pull <ECR_URL>:latest

docker run -d \
  --name banking-api \
  --restart unless-stopped \
  -p 8080:8080 \
  -e APP_ENV=staging \
  -e APP_PORT=8080 \
  -e CACHE_ENABLED=true \
  -e RATE_LIMIT_ENABLED=true \
  -e CIRCUIT_BREAKER_ENABLED=true \
  <ECR_URL>:latest
```

## Akses API Setelah Deploy

```bash
# Ambil ALB DNS
ALB_DNS=$(terraform output -raw alb_dns_name)

# Test
curl http://$ALB_DNS/api/v1/accounts/1001/balance
```

## Jalanin k6 ke AWS

```bash
ALB_DNS=$(terraform output -raw alb_dns_name)
k6 run -e BASE_URL=http://$ALB_DNS scripts/load-test/baseline.js
k6 run -e BASE_URL=http://$ALB_DNS scripts/load-test/optimized.js
```

## Destroy (biar tidak boros kredit)

```bash
terraform destroy
```

> Selalu destroy kalau sudah selesai testing! Kredit VOCLabs $50 habis dalam ~13 hari kalau dibiarkan nyala terus.

## Estimasi Biaya (us-east-1, staging)

| Resource | Estimasi/jam |
|----------|-------------|
| EC2 t3.medium | ~$0.052 |
| RDS t3.micro x2 | ~$0.068 |
| ElastiCache t3.micro | ~$0.017 |
| ALB | ~$0.022 |
| **Total** | **~$0.16/jam (~$3.8/hari)** |
