# Domain Setup Guide

## Overview

This guide helps you configure DNS and SSL certificates for your Jitsi Meet platform deployment.

## Prerequisites

- Deployed Terraform infrastructure (VPC, Load Balancer, ECS)
- Domain registered and managed in Route 53
- Access to AWS Certificate Manager

## Step 1: DNS Configuration

### 1.1 Create CNAME Record

In your Route 53 hosted zone:

1. **Go to Route 53** → Hosted zones → Your domain
2. **Click "Create record"**
3. **Configure record:**
   - **Record name:** `meet` (or your preferred subdomain)
   - **Record type:** `CNAME`
   - **Value:** Your load balancer DNS name (from Terraform output `load_balancer_dns_name`)
   - **TTL:** `300` seconds
4. **Click "Create records"**

### 1.2 Verify DNS Resolution

Test DNS resolution:
```bash
nslookup meet.yourdomain.com
```

Should return your load balancer's IP addresses.

## Step 2: SSL Certificate

### 2.1 Request Certificate

In AWS Certificate Manager (same region as your load balancer):

1. **Go to Certificate Manager**
2. **Click "Request a certificate"**
3. **Configure certificate:**
   - **Certificate type:** Request a public certificate
   - **Domain name:** `meet.yourdomain.com`
   - **Validation method:** DNS validation (recommended)
   - **Key algorithm:** RSA 2048 (most compatible)
   - **Export:** Disable export (for AWS-only use)

### 2.2 Add Validation Records

1. **After requesting**, certificate shows "Pending validation"
2. **Click certificate ID** to view details
3. **Copy DNS validation records** (CNAME name and value)
4. **Add validation records** to your Route 53 hosted zone
5. **Wait for validation** (usually 5-30 minutes)

### 2.3 Certificate Tags (Recommended)

Add these tags for organization:
- `Project`: `jitsi-video-platform`
- `Environment`: `production`
- `Purpose`: `video-conferencing`

## Step 3: Configure Load Balancer HTTPS

Once certificate is validated:

1. **Note certificate ARN** from Certificate Manager
2. **Update Terraform** to add HTTPS listener with certificate
3. **Apply changes** to enable HTTPS traffic

## Troubleshooting

**DNS not resolving:**
- Check CNAME record configuration
- Wait for DNS propagation (up to 48 hours globally)
- Verify load balancer is healthy

**Certificate validation failing:**
- Ensure validation records are added correctly to Route 53
- Check domain ownership
- Verify DNS propagation of validation records

**HTTPS not working:**
- Confirm certificate status is "Issued"
- Check load balancer listener configuration
- Verify security group allows port 443