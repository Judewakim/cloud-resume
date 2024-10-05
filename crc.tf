//cloud resume challenge
//manually add the bucket policy from below (convert to json)
//add api url to index.html (from outputs of this file)
//upload index.html to bucket
//manually purchase the domain you want in route53
//manually input the domain name into data aws_route53_zone primary
//manually confirm/update NS on registered domains in route53 w new NS from hosted zone record (no periods at the end)


provider "aws" {
  region = "us-east-1"
}

locals {
  s3_origin_id = "myS3Origin"
}

#S3
resource "aws_s3_bucket" "cloud_resume" {
  bucket = "cloud-resume-challenge-vvakim-bucket"
}

#S3 website config
resource "aws_s3_bucket_website_configuration" "cloud_web_config" {

  bucket = aws_s3_bucket.cloud_resume.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

#Makes S3 bucket public
resource "aws_s3_bucket_public_access_block" "s3_public_access" {
  bucket = aws_s3_bucket.cloud_resume.id

  block_public_acls   = false
  ignore_public_acls  = false
  block_public_policy = false
  restrict_public_buckets = false
}

#S3 bucket policy
resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = aws_s3_bucket.cloud_resume.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = "*"
        Action = "s3:GetObject"
        Resource = "arn:aws:s3:::cloud-resume-challenge-vvakim-bucket/*"
      }
    ]
  })
}

#ACM cert
resource "aws_acm_certificate" "cert" {
  domain_name = data.aws_route53_zone.primary.name
  validation_method = "DNS"

  subject_alternative_names = [ "www.${data.aws_route53_zone.primary.name}" ]

  lifecycle {
    create_before_destroy = true
  }
}

#ACM cert validation
resource "aws_acm_certificate_validation" "cert_validation" {
  certificate_arn = aws_acm_certificate.cert.arn
  //maybe validation_record_fqdns
}

# //maybe 
# resource "aws_lb_listener" "example" {
#   # ... other configuration ...

#   certificate_arn = aws_acm_certificate_validation.example.certificate_arn
# }

#//Add everything manually
# resource "aws_route53_domain_registration" "domain" {
#   domain_name       = "domainname.com"
#   admin_contact {
#     name         = "Admin Name"
#     organization = "Organization Name"
#     address_line_1 = "123 Main St"
#     city         = "City"
#     state        = "State"
#     country      = "US"
#     zip_code     = "12345"
#     email        = "admin@example.com"
#     phone_number = "+1.1234567890"
#   }
#   registrant_contact {
#     name         = "Registrant Name"
#     organization = "Organization Name"
#     address_line_1 = "123 Main St"
#     city         = "City"
#     state        = "State"
#     country      = "US"
#     zip_code     = "12345"
#     email        = "registrant@example.com"
#     phone_number = "+1.1234567890"
#   }
#   tech_contact {
#     name         = "Tech Name"
#     organization = "Organization Name"
#     address_line_1 = "123 Main St"
#     city         = "City"
#     state        = "State"
#     country      = "US"
#     zip_code     = "12345"
#     email        = "tech@example.com"
#     phone_number = "+1.1234567890"
#   }
#   privacy_protection = true
# }

# resource "aws_route53_zone" "primary" {
#   name = aws_route53_domain_registration.domain.domain_name
# }
#//If you decide to get the domain name from this file uncomment above aws_route53_zone and comment out the one below

#Route53 domain name that get manually added
data "aws_route53_zone" "primary" {
  name = "wakim-works.com"//MANUALLY ADD
}

resource "aws_route53_zone" "primary" {
  name = data.aws_route53_zone.primary.name
}

resource "aws_route53_record" "route_record" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  zone_id = aws_route53_zone.primary.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60
}


#CloudFront cache policy
resource "aws_cloudfront_cache_policy" "distro_cache_policy" {
    name = "distro-policy"
    min_ttl = 1
    default_ttl = 50
    max_ttl = 100

    parameters_in_cache_key_and_forwarded_to_origin {
      cookies_config {
        cookie_behavior = "whitelist"
        cookies {
          items = [ "idk" ] //figure that value out
        }
      }

      headers_config {
        header_behavior = "whitelist"
        headers {
          items = [ "idk" ] //figure that value out
        }
      }

      query_strings_config {
        query_string_behavior = "whitelist"
        query_strings {
          items = [ "idk" ] //figure that value out
        }
      }
    }
}

#CloudFront distribution
resource "aws_cloudfront_distribution" "cloud_resume_distro" {
    enabled = true
    is_ipv6_enabled = true
    default_root_object = "index.html"
    comment = "distro for resume challenge"

    origin {
      domain_name = aws_s3_bucket.cloud_resume.bucket_regional_domain_name
      origin_id = local.s3_origin_id
    }


    restrictions {
      geo_restriction {
        restriction_type = "whitelist"
        locations = [ "US", "CA", "GB", "DE" ]
      }
    }

    viewer_certificate {
      acm_certificate_arn = aws_acm_certificate.cert.arn
      ssl_support_method = "sni-only"
      minimum_protocol_version = "TLSv1.2_2018"
    }

    default_cache_behavior {
      viewer_protocol_policy = "redirect-to-https"
      target_origin_id = local.s3_origin_id
      allowed_methods = [ "GET", "HEAD", "OPTIONS" ]
      cached_methods = [ "GET", "HEAD", "OPTIONS" ]
      cache_policy_id = aws_cloudfront_cache_policy.distro_cache_policy.id
    }

    aliases = [ data.aws_route53_zone.primary.name, "www.${data.aws_route53_zone.primary.name}" ]
}

#A records in Route53
resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = "www.${data.aws_route53_zone.primary.name}"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.cloud_resume_distro.domain_name
    zone_id                = aws_cloudfront_distribution.cloud_resume_distro.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "no-www" {
  zone_id = aws_route53_zone.primary.zone_id
  name    = data.aws_route53_zone.primary.name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.cloud_resume_distro.domain_name
    zone_id                = aws_cloudfront_distribution.cloud_resume_distro.hosted_zone_id
    evaluate_target_health = false
  }
}

#DynamoDB
resource "aws_dynamodb_table" "visitor_count" {
  name         = "crcVisitorCount"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

#IAM
data "aws_iam_policy_document" "iam_policy_doc" {
  statement {
    principals {
      type        = "AWS"
      identifiers = ["123456789012"]
    }

    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]

    resources = [
      aws_s3_bucket.cloud_resume.arn,
      "${aws_s3_bucket.cloud_resume.arn}/*",
    ]
  }
}

resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda_exec_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy" "lambda_policy" {
  name = "crc_lambda_policy"
  //dynamoDB full access
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "dynamodb:*",
                "s3:*",
                "s3:GetBucketAcl",
                "s3:PutBucketAcl",
                "dax:*",
                "application-autoscaling:DeleteScalingPolicy",
                "application-autoscaling:DeregisterScalableTarget",
                "application-autoscaling:DescribeScalableTargets",
                "application-autoscaling:DescribeScalingActivities",
                "application-autoscaling:DescribeScalingPolicies",
                "application-autoscaling:PutScalingPolicy",
                "application-autoscaling:RegisterScalableTarget",
                "cloudwatch:DeleteAlarms",
                "cloudwatch:DescribeAlarmHistory",
                "cloudwatch:DescribeAlarms",
                "cloudwatch:DescribeAlarmsForMetric",
                "cloudwatch:GetMetricStatistics",
                "cloudwatch:ListMetrics",
                "cloudwatch:PutMetricAlarm",
                "cloudwatch:GetMetricData",
                "ec2:DescribeVpcs",
                "ec2:DescribeSubnets",
                "ec2:DescribeSecurityGroups",
                "iam:GetRole",
                "iam:ListRoles",
                "lambda:CreateFunction",
                "lambda:ListFunctions",
                "lambda:ListEventSourceMappings",
                "lambda:CreateEventSourceMapping",
                "lambda:DeleteEventSourceMapping",
                "lambda:GetFunctionConfiguration",
                "lambda:DeleteFunction",
                "resource-groups:ListGroups",
                "resource-groups:ListGroupResources",
                "resource-groups:GetGroup",
                "resource-groups:GetGroupQuery",
                "resource-groups:DeleteGroup",
                "resource-groups:CreateGroup",
                "tag:GetResources"
            ],
            "Effect": "Allow",
            "Resource": "*"
        },
        {
            "Action": "cloudwatch:GetInsightRuleReport",
            "Effect": "Allow",
            "Resource": "arn:aws:cloudwatch:*:*:insight-rule/DynamoDBContributorInsights*"
        },
        {
            "Action": [
                "iam:PassRole"
            ],
            "Effect": "Allow",
            "Resource": "*",
            "Condition": {
                "StringLike": {
                    "iam:PassedToService": [
                        "application-autoscaling.amazonaws.com",
                        "application-autoscaling.amazonaws.com.cn",
                        "dax.amazonaws.com"
                    ]
                }
            }
        },
        {
            "Effect": "Allow",
            "Action": [
                "iam:CreateServiceLinkedRole"
            ],
            "Resource": "*",
            "Condition": {
                "StringEquals": {
                    "iam:AWSServiceName": [
                        "replication.dynamodb.amazonaws.com",
                        "dax.amazonaws.com",
                        "dynamodb.application-autoscaling.amazonaws.com",
                        "contributorinsights.dynamodb.amazonaws.com",
                        "kinesisreplication.dynamodb.amazonaws.com"
                    ]
                }
            }
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attach" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

#Lambda
resource "aws_lambda_function" "visitor_count" {
  filename         = "lambda_function_payload.zip"
  function_name    = "visitor_count"
  role             = aws_iam_role.lambda_exec_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.12"
  source_code_hash = data.archive_file.lambda.output_base64sha256
}

data "archive_file" "lambda" {
  type        = "zip"
  source_file = "lambda_function.py"
  output_path = "lambda_function_payload.zip"
}

#API Gateway
resource "aws_api_gateway_rest_api" "visitor_api" {
  name        = "visitor_api"
  description = "API for visitor count"
}

resource "aws_api_gateway_resource" "visitor_resource" {
  rest_api_id = aws_api_gateway_rest_api.visitor_api.id
  parent_id   = aws_api_gateway_rest_api.visitor_api.root_resource_id
  path_part   = "visitor-count"
}

resource "aws_api_gateway_method" "visitor_method" {
  rest_api_id   = aws_api_gateway_rest_api.visitor_api.id
  resource_id   = aws_api_gateway_resource.visitor_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_lambda_permission" "api_gateway_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.visitor_count.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.visitor_api.execution_arn}/*/GET/visitor-count"
}

resource "aws_api_gateway_integration" "visitor_integration" {
  rest_api_id             = aws_api_gateway_rest_api.visitor_api.id
  resource_id             = aws_api_gateway_resource.visitor_resource.id
  http_method             = aws_api_gateway_method.visitor_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.visitor_count.invoke_arn
}

resource "aws_api_gateway_deployment" "visitor_deployment" {
  depends_on  = [aws_api_gateway_integration.visitor_integration]
  rest_api_id = aws_api_gateway_rest_api.visitor_api.id
  stage_name  = "prod"
}

#Outputs (move to dif file)
output "website_url" {
  value = "${aws_s3_bucket_website_configuration.cloud_web_config.website_endpoint}"
}

output "api_url" {
  value = "${aws_api_gateway_deployment.visitor_deployment.invoke_url}/visitor-count"
}

output "distribution_url" {
  value = "${aws_cloudfront_distribution.cloud_resume_distro.domain_name}"
}

output "zone_id" {
  value = data.aws_route53_zone.primary.zone_id
}
