
provider "aws" {
  region  = "ap-south-1"
  profile = "rohan"	
}

resource "aws_key_pair" "terrakey" {
  key_name   = "terrakey"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAABJQAAAQEAtsmw2UBWuXtxnaG8vKYSvyO1h7/ecGy+IQ9potLJOjP0NG5F13JCMbJRNYRoez9wW2iKDh3riSbP7JHoMG5IGoDXWmHunB1GUxPCDetK4p4mlJj700BA5mfMR8CRMkN1Xn2lvzFh9fKgt2XOoFkF5yH1jqLwy7Nyjv+ayZDmtbW6yqvj7MzNohDcetucZTIpD2Zlxjkd3T+bZcHjl7CqeOzjpn7hbcxojvQvHpTzeeH2jY5q/C3TQJgCEuC7bxCF5dMEVErhXVK8SR0EyhrZg2xbzdMWN/Q6BxaAsQnOMoSTAX3Q+4z9KdRxDcDPjeR97sUk3ShWBUG9QkyVJj+4fQ== rsa-key-20200611"
}

resource "aws_security_group" "allow_http" {
  name        = "allow_http"
  description = "Allow http inbound traffic"

  ingress {
    description = "http from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
ingress {
    description = "ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_http"
  }
}

output "sgid"{
  value=aws_security_group.allow_http
}
resource "aws_instance" "myInstance" {
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name = "terrakey"
  security_groups = ["allow_http",]
tags = {
    Name = "terra ec2"
}
}
output "osip" {
	value=aws_instance.myInstance.public_ip
}
/*
output "osop"{
value=aws_instance.myInstance
}
output "ebs"{
value=aws_ebs_volume.webdata
}
*/
resource "aws_ebs_volume" "webdata" {
  availability_zone = aws_instance.myInstance.availability_zone
  size              = 1

  tags = {
    Name = "webdata"
  }
}


resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.webdata.id
  instance_id = aws_instance.myInstance.id
  force_detach=true	
}

resource "null_resource" "remotecmds" {
 depends_on = [
    aws_volume_attachment.ebs_att,
  ]
 connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/Rohan/Desktop/AWS/rightterra.pem")
    host     = aws_instance.myInstance.public_ip
  }
  provisioner "remote-exec" {
    inline = [
      
	"sudo yum install git httpd php -y",
	"sudo mkfs.ext4 /dev/xvdh",
	"sudo mount /dev/xvdh /var/www/html",
	"sudo rm -rf /var/www/html/*",
 	"sudo git clone https://github.com/18uec075/webdata.git /var/www/html",
	"sudo systemctl restart httpd",
	"sudo systemctl enable httpd",
	    ]
  }
}
  		  

resource "null_resource" "chrome" {
 depends_on = [
    null_resource.remotecmds,
  ]
 provisioner "local-exec" {
	command = "microsoftedge ${aws_instance.myInstance.public_ip}"
  }
}



resource "aws_s3_bucket" "bucket" {
    bucket  = "terrabuck1"
    acl     = "public-read"
provisioner "local-exec" {
        command     = "git clone https://github.com/18uec075/image.git C:/Users/Rohan/Desktop/terra/proj/git-image"
    }
provisioner "local-exec" {
        when        =   destroy
        command     =   "echo Y | rmdir /S git-image"
    }
}
output "buck"{
  value=aws_s3_bucket.bucket
}

resource "aws_s3_bucket_object" "image-upload" {
  depends_on=[
    aws_s3_bucket.bucket,
  ]
    bucket  = aws_s3_bucket.bucket.bucket
    key     = "image.png"
    source  = "C:/Users/Rohan/Desktop/terra/proj/git-image/download.png"
    acl     = "public-read"
    content_type = "image/png"
}

resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = "Some comment"
}
output "originaccessidentity"{
  value=aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.bucket.bucket_domain_name
    origin_id   = "imagebucketterra"
    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path
    }
  }
  enabled             = true
  is_ipv6_enabled     = true
   default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "imagebucketterra"
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }
   restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
    viewer_certificate {
    cloudfront_default_certificate = true
  }
  }
  
output "cflink" {
  value =aws_cloudfront_distribution.s3_distribution.domain_name
}

//updating bucket policy

data "aws_iam_policy_document" "s3_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.bucket.arn}/*"]
principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn]
    }
  }
statement {
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.bucket.arn]
principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn]
    }
  }
}
resource "aws_s3_bucket_policy" "bucketpolicy" {
  bucket = aws_s3_bucket.bucket.id
  policy = data.aws_iam_policy_document.s3_policy.json
}

resource "null_resource" "imagesite" {
 depends_on = [
    aws_volume_attachment.ebs_att,aws_cloudfront_distribution.s3_distribution,
  ]

 connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/Rohan/Desktop/AWS/rightterra.pem")
    host     = aws_instance.myInstance.public_ip
  }


  provisioner "remote-exec" {
    inline = [
      
	"sudo echo >>EOF \"<img src=${aws_cloudfront_distribution.s3_distribution.domain_name}/image.png />\" > /var/www/html/index.html",
	"sudo systemctl restart httpd",
	    ]
  }
}

resource "null_resource" "edgeimage" {
 depends_on = [
    null_resource.remotecmds,null_resource.imagesite,
  ]
 provisioner "local-exec" {
	command = "microsoftedge ${aws_instance.myInstance.public_ip}"
  }
}

