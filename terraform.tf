provider "aws" {
  region = "ap-south-1"
  profile = "shrashti03"
}


#creating a key pair

resource "tls_private_key" "task1-key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
resource "aws_key_pair" "task1-key" {
  key_name   = "task1key"
  public_key = tls_private_key.task1-key.public_key_openssh
}

# saving key to local file
resource "local_file" "task1-key" {
    content  = tls_private_key.task1-key.private_key_pem
    filename = "/root/terraform/task1key.pem"
}



#creating a security group 

resource "aws_security_group" "security_group_2" {
  name        = "security_group_2"
  description = "Allow ssh and http traffic"
  
  ingress {
    
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  
}

#creating an ec2 instance

resource "aws_instance" "web" {
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name = "task1key"
  security_groups = ["${aws_security_group.security_group_2.name}"]

  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = tls_private_key.task1-key.private_key_pem
    host     = aws_instance.web.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd  php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  }

  tags = {
    Name = "lwos1"
  }

}
#creating  an volume

resource "aws_ebs_volume" "esb1" {
  availability_zone = aws_instance.web.availability_zone
  size              = 1
  tags = {
    Name = "lwebs"
  }
}

#attaching a volume to an instance

resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/sdh"
  volume_id   = "${aws_ebs_volume.esb1.id}"
  instance_id = "${aws_instance.web.id}"
  force_detach = true
}
#creating s3 bucket
resource "aws_s3_bucket" "shrashti" {
  bucket = "shrashti0310"
  acl    = "public-read"

provisioner "local-exec" {
        command     = "git clone https://github.com/Shrashti0310/webserver  bonz"
    }

provisioner "local-exec" {
        when        =   destroy
        command     =   "echo Y | rmdir /s  bonz"
    }

   tags = {
    Name = "shrashti0310"
    
  }
}
# uploading image on s3 bucket
resource "aws_s3_bucket_object" "imageupload" {
  bucket = "${aws_s3_bucket.shrashti.bucket}"
  key    = "kandy"
  source = "bonz/kandy.jpg"
  acl     = "public-read"
 
}
locals {
  
s3_origin_id = aws_s3_bucket.shrashti.bucket
  
image_url = "${aws_cloudfront_distribution.s3-disttribute.domain_name}/${aws_s3_bucket_object.imageupload.key}"

}

#creating cloudfront distribution

resource "aws_cloudfront_distribution" "s3-disttribute" {
  origin {
    domain_name = "${aws_s3_bucket.shrashti.bucket_regional_domain_name}"
    origin_id   = "${local.s3_origin_id}"

  }
 enabled             = true
default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${local.s3_origin_id}"

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





output "myos_ip" {
  value = aws_instance.web.public_ip
}


resource "null_resource" "nulllocal2"  {
	provisioner "local-exec" {
	    command = "echo  ${aws_instance.web.public_ip} > publicip.txt"
  	}
}



resource "null_resource" "nullremote3"  {

depends_on = [
    aws_volume_attachment.ebs_att,aws_cloudfront_distribution.s3-disttribute
  ]


  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = tls_private_key.task1-key.private_key_pem
    host     = aws_instance.web.public_ip
  }

provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4  /dev/xvdh",
      "sudo mount  /dev/xvdh  /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/Shrashti0310/webserver.git /var/www/html/",
      "sudo su << EOF",
           "echo \"<img src='http://${aws_cloudfront_distribution.s3-disttribute.domain_name}/${aws_s3_bucket_object.imageupload.key}' width=500 height=500>\" >> /var/www/html/test.html",
      "EOF",
      
      
    ]
  }
}

#open the website in chrome

resource "null_resource" "nulllocal1"  {


depends_on = [
    null_resource.nullremote3,
  ]

	provisioner "local-exec" {
	    command = " start chrome  ${aws_instance.web.public_ip}"
  	}
}
