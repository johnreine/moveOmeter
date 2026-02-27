#!/bin/bash
# moveOmeter Deployment Configuration
# This file stores deployment settings so we don't have to ask repeatedly

# Digital Ocean Server
SERVER_IP="167.71.107.200"
SSH_USER="root"
DEPLOY_TARGET="${SSH_USER}@${SERVER_IP}"

# Deployment paths
REMOTE_WEB_DIR="/var/www/moveometer"
LOCAL_DASHBOARD_DIR="../web/dashboard"

# Export for use in other scripts
export SERVER_IP
export SSH_USER
export DEPLOY_TARGET
export REMOTE_WEB_DIR
export LOCAL_DASHBOARD_DIR
