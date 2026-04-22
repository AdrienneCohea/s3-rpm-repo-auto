#!/bin/bash
set -e

echo "Are you sure you want to destroy all resources? (y/n)"
read -r response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    cd terraform
    terraform destroy -auto-approve
else
    echo "Cleanup cancelled."
fi
