#!/usr/bin/env bash
# Deploys ./app to the Azure VM and restarts the container.
# Required env: VM_IP, SSH_KEY (path to private key), SSH_USER
# Optional env: APP_VERSION, GIT_SHA
set -euo pipefail

: "${VM_IP:?VM_IP is not set}"
: "${SSH_KEY:?SSH_KEY is not set}"
: "${SSH_USER:?SSH_USER is not set}"
REMOTE=/opt/tourguide
SSH="ssh -i $SSH_KEY -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=15 -o LogLevel=ERROR"

echo "Waiting for the VM to accept SSH and finish cloud-init (Docker install)..."
for i in $(seq 1 30); do
  if $SSH "$SSH_USER@$VM_IP" "test -f $REMOTE/.cloud-init-done && docker --version" >/dev/null 2>&1; then
    echo "VM is ready."
    break
  fi
  if [ "$i" -eq 30 ]; then echo "VM was not ready after 10 minutes" >&2; exit 1; fi
  echo "  not ready yet ($i/30), retrying in 20s"
  sleep 20
done

echo "Copying app files..."
rsync -az --delete \
  --exclude '.venv' --exclude 'tests' --exclude '__pycache__' \
  --exclude '.pytest_cache' --exclude 'test-results.xml' --exclude '.env' \
  -e "$SSH" app/ "$SSH_USER@$VM_IP:$REMOTE/"

echo "Starting container (build ${APP_VERSION:-dev})..."
$SSH "$SSH_USER@$VM_IP" "cd $REMOTE && printf 'APP_VERSION=%s\nGIT_SHA=%s\n' '${APP_VERSION:-dev}' '${GIT_SHA:-local}' > .env && docker compose up -d --build && docker image prune -f >/dev/null"
echo "Deploy finished."
