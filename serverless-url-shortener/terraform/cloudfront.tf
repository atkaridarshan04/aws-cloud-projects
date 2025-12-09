############################################
# --- CloudFront Origin Access Control --- #
############################################

# Origin Access Control (OAC) (replaces the older OAI approach).
# It securely signs requests from CloudFront to S3.
resource "aws_cloudfront_origin_access_control" "frontend_oac" {
  name                             = "frontend-oac"
  description                      = "CloudFront OAC for frontend"
  origin_access_control_origin_type = "s3"      # The origin type this OAC applies to
  signing_behavior                 = "always"   # Always sign requests to S3
  signing_protocol                 = "sigv4"    # Use SigV4 signing (required for OAC)
}

########################################
# --- CloudFront Distribution Setup --- #
########################################

# Creates the CloudFront CDN distribution
resource "aws_cloudfront_distribution" "frontend_cdn" {
  # Define S3 as the origin
  origin {       
    # Regional S3 endpoint (required for OAC)
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name

    # Identifier for this origin
    origin_id                = var.frontend_bucket_name

    # Attach the Origin Access Control
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend_oac.id
  }

  enabled             = true            # Enables the distribution
  default_root_object = "index.html"    # Default file served when accessing the root URL

  # Default Cache Behavior
  default_cache_behavior {
    # Only allow read-only HTTP methods
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = var.frontend_bucket_name     # Link this behavior to the S3 origin
    viewer_protocol_policy = "redirect-to-https"          # Redirect HTTP requests to HTTPS

    # Disable query string forwarding for better caching
    forwarded_values {
      query_string = false
      # Do not forward cookies to the origin
      cookies {
        forward = "none"
      }
    }
  }

##################################
# Geo Restrictions
##################################
# Geo restriction = controlling access based on the visitor’s country. 
# CloudFront looks at the IP address of the viewer, maps it to a country, and then: 'Allows' the Request or 'Block' it
  restrictions {
    geo_restriction {
      # No geo-blocking enabled (i.e., allow all countries)
      restriction_type = "none"
    }
  }

  # SSL / TLS Configuration
  viewer_certificate {
    # Uses CloudFront default SSL certificate (*.cloudfront.net)
    cloudfront_default_certificate = true
  }

  comment    = "Frontend CloudFront Distribution"   # Optional description for clarity
  web_acl_id = aws_wafv2_web_acl.frontend_waf.arn   # Attach AWS WAF to protect the distribution
}

#############################
# --- AWS WAF v2 Setup --- #
#############################

# Web Application Firewall for CloudFront
# Must be created in us-east-1 for CloudFront scope
resource "aws_wafv2_web_acl" "frontend_waf" {
  provider = aws.us_east_1

  name        = "frontend-waf"
  description = "WAF for frontend CloudFront"
  scope       = "CLOUDFRONT"

  # Default behavior is to 'allow' requests unless blocked by rules
  default_action {
    allow {}
  }

  # WAF Visibility & Metrics
  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "frontendWAF"
    sampled_requests_enabled   = true
  }

  # AWS Managed Rules - Common Set
  rule {
    name     = "AWS-AWSManagedRulesCommonRuleSet"
    priority = 1

    # Use managed rules as-is (no overrides)
    override_action {
      none {}
    }

    statement {
      # Use AWS managed rule group for common threats (e.g: SQL injection, XSS, etc.)
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    # Per-rule logging and metrics
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "commonRule"
      sampled_requests_enabled   = true
    }
  }
}
