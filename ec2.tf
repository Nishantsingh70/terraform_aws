provider "aws" {

    region  =  "ap-south-1"
    profile  =  "nishu"
}
resource "tls_private_key" "my_key_pair1"  {
   algorithm  =  "RSA"
 }

resource "aws_key_pair" "key1"  {
    key_name  =  "my_key_pair1"
    public_key  = "${tls_private_key.my_key_pair1.public_key_openssh}"
  
    depends_on  =  [ 
               tls_private_key.my_key_pair1
       ]
}
resource "aws_security_group" "my_se_group" {
    depends_on = [
                   aws_key_pair.key1
       ]
        name           =  "my_se_group"
        description  =  "Allow SSH and HTTP"
      
        ingress { 
           description   =  "SSH"
           from_port     =  22
           to_port         =  22
           protocal       =  "tcp"
           cidr_blocks  =  [ "0.0.0.0/0"]
         }
        
         ingress {
            description   =  "HTTP"
            from_port     =  80
            to_port         =  80
            protocal        =  "tcp"
            cidr_blocks   =  [ "0.0.0.0/0" ]
         }
         egress {
             from_port  =  0
             to_port      =  0
             protocal    =  "-1"
             cidr_blocks  =  [ "0.0.0.0/0" ]
        }
       tags  =  {
           Name  =  "my_sec_group"
        }
}
resource "aws_instance"  "my_inst"  {
    ami   =  "ami-0447a12f28fddb066"
    instance_type  =  "t2.micro"
    key_name  =  "aws_key_pair.key1.key_name"
    security_groups  =  [ "my_se_group" ]
    
    provisioner  "remote-exec" {
              connection  {
                  agent   =  "false"
                  type     =  "ssh"
                  user     =  "ec2-user"
                  private_key  =  "${tls_private_key.my_key_pair.private_key_pem}"
                  host     =  "${aws_instance.myinst.public_ip}"
  }
      inline  =  [ 
           "sudo  yum install httpd  php  git  -y",
           "sudo  systemctl  restart  httpd",
           "sudo systemctl  enable httpd"
         ]
  }
 
   tags  =  {
        Name = "myos1"
     }
}

output "availzone" {
        value  =  aws_instance.myinst.availability_zone
}

output "publicip" {
        value  =  aws_instance.myinst.public_ip
}

resource "aws_ebs_volume" "my_ebs_volume" {
        availability_zone  =  aws_instance.myinst.availability_zone
        size  =  1
        tags  =  {
            Name  =  "my_ebs_volume"
        }
}
resource "aws_vloume_attachment"  "ebs_attachment"  {
         device_name  =  "/dvd/sdf"
         volume_id  =  aws_ebs_volume.my_esb_volume.id
         instance_id  =  aws_instance.myinst.id
         force_detact  =  true 
  }



resource  "null_resource"  "mounting" {
      depends_on = [
            aws_volume_attachment.ebs_attachment,
      ]
      connection {
             agent  =  "false"
             type  =  "ssh"
             user  =  "ec2-user"
             private_key  =  "${tls_private_key.my_key_pair1.private_key_pem}"
             host  =  "${aws_instance.myinst.public_ip}"
       }
      provisioner  "remote-exec" {
             inline  =  [
                 "sudo  mkfs.ext4  /dev/xvdf",
                 "sudo mount /dev/xvdf1  /var/www/html",
                 "sudo rm -rf /var/www/html/*",
                 "sudo git clone https://github.com/Nishantsingh70/terraform_aws.git    /var/www/html"
             ]
         }
    }

resource "aws_s3_bucket"  "bucket"  {
            bucket  =  "my_bucket"
            ac1  =  "private"
            force_destroy  =  "true"
        versioning {
                       enabled  =  true
        }
       tags  =  {
           Name  =  "my_bucket" 
        }
}
resource "null_resource" "git_down" {
         depends_on  =  [ 
                   aws_s3_bucket.bucket 
          ]
         provisioner "local-exec" {
                  command  =  "git clone https://github.com/Nishantsingh70/terraform_aws.git"
         }
  } 
resource "aws_s3_bucket_object"  "my_bucket_object"  {
          depends_on  =  [
                      aws_s3_bucket.my_bucket , null_resources.git_down 
         ]
          bucket  =  "${aws_s3_bucket.my_bucket.id}"
          key   =  "img.jpg"  
          source  =  "terraform_aws/img.jpg"
          ac1  =  "public-read"
   }
output "Image" {
      value  =  aws_s3_bucket_object.my_bucket_object
}

resource "aws_cloudfront_distribution" "s3_cloudfront1" {
        depends_on = [
                  aws_s3_bucket.my_bucket , null_resource.git_down
        ]
        origin {
                domain_name = "${aws_s3_bucket.my_bucket.bucket_regional_domain_name}"
                origin_id   = "S3-my_bucket-id"
                custom_origin_config  {
                      http_port  =  80
                      https_port  =  80
                      origin_protocal_policy  =  "match-viewer"
                      origin_ss1_protocals  =  [ "TLSv1" , "TLSv1.1" , "TLSv1.2" ]
           }
}
enabled  =  true
default_cache_behaviour {
            allowed_methods  =  ["DELETE" , "GET" , "HEAD" , "OPTIONS" , "PATCH" , "POST" , "PUT" ]
            cached_methods = ["GET" , "HEAD"]
            target_origin_id  =  "${local.s3-my_bucket-id}"
        
            forwarded_values  {
                query_string  =  false
                 cookies {
                               forward = "none"
                 }
 }
viewer_protocal_policy  =  "allow-all"
min_ttl  =  0
default_ttl  =  3600
max_ttl  =  86400
}
restrictions  { 
             geo_restriction {
                              restriction_type = "none"
          }
}
viewer_certificate  {
           cloudfront_default_certificate = true
           }

output "domain-name" {
	value = aws_cloudfront_distribution.s3_cloudfront1.domain_name

}
resource "null_resource" "remote" {
        depends_on  =  [
             null_reource.mounting,
    ]
}
   provisioner  "local-exec"  {
           command  =  "google-chrome ${aws_instance.myinst.public_ip}"
   }

