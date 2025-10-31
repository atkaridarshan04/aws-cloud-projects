# AWS Secure Static Website Hosting

A production-ready reference for deploying a **secure static website** on **AWS** using **S3**, **CloudFront CDN**, **Origin Access Control (OAC)**, **IAM**, and **AWS WAF**. This implementation follows security best practices by keeping S3 buckets private and serving content exclusively through CloudFront.

This repo includes two end-to-end deployment paths:

* **AWS Management Console** (click-through)
* **Terraform** (Infrastructure as Code)

## Architecture

![s3-cloudfront-architecture](./docs/images/s3-cloudfront-architecture.png)

### Core Components

1. **Amazon S3** - Private bucket storing static website files (HTML, CSS, JS, images)
2. **Amazon CloudFront** - Global CDN for fast content delivery with edge caching
3. **Origin Access Control (OAC)** - Secure access mechanism allowing only CloudFront to access S3
4. **AWS IAM** - Identity and access management for secure resource permissions
5. **AWS WAF** - Web Application Firewall for protection against malicious traffic
6. **Route 53** (Optional) - DNS management for custom domain names

## Architecture Flow

The application follows a **secure static hosting pattern** with clear separation of concerns:

1. **Content Storage (Private S3)**
   * Static website files (HTML, CSS, JavaScript, images) are stored in a **private S3 bucket**
   * Direct public access to S3 is blocked using bucket policies and access controls
   * S3 serves as the origin for CloudFront distribution

2. **Content Delivery (CloudFront CDN)**
   * **CloudFront distribution** acts as the public-facing endpoint for the website
   * **Origin Access Control (OAC)** ensures only CloudFront can access S3 content
   * Global edge locations provide low-latency content delivery worldwide
   * Automatic HTTPS encryption and HTTP to HTTPS redirection

3. **Security Layer (WAF + IAM)**
   * **AWS WAF** filters malicious requests before they reach CloudFront
   * **IAM policies** enforce least-privilege access to AWS resources
   * **Security headers** and **CORS policies** protect against common web vulnerabilities

4. **DNS & Domain Management (Optional)**
   * **Route 53** provides DNS resolution for custom domains
   * **SSL/TLS certificates** via AWS Certificate Manager for HTTPS

---

### End-to-End Flow Example:
1. User requests website → DNS resolves to **CloudFront distribution**
2. CloudFront checks edge cache → if miss, requests content from **S3 origin**
3. **OAC** authenticates CloudFront's request to S3
4. S3 returns content → CloudFront caches and serves to user
5. **WAF** filters malicious requests before they reach CloudFront
6. Subsequent requests served from edge cache for improved performance

---

### Why This Design

* **Highly secure**: Private S3 bucket with OAC, no direct public access
* **Global performance**: CloudFront edge locations reduce latency worldwide  
* **Cost-effective**: S3 storage pricing + CloudFront data transfer optimization
* **Scalable**: Handles traffic spikes automatically through CDN caching
* **Production-ready**: WAF protection, HTTPS enforcement, monitoring capabilities

## What You'll Deploy

* Private S3 bucket with static website files
* CloudFront distribution with custom cache behaviors
* Origin Access Control (OAC) for secure S3 access
* IAM roles and policies for resource permissions
* AWS WAF with basic security rules
* Optional: Route 53 hosted zone and SSL certificate

> **Security Note:** This implementation keeps S3 buckets completely private. All public access is routed through CloudFront, providing better security, performance, and cost optimization.

## Application Overview

![web](./docs/images/web.png)

The deployed website demonstrates:
- Fast global content delivery via CloudFront
- Secure private S3 bucket configuration  
- Automatic HTTPS encryption
- WAF protection against common attacks

## Quick Start

Pick one of the deployment guides:

* **[Deploy with AWS Console](./docs/console.md)**
* **[Deploy with Terraform](./docs/terraform.md)**

---