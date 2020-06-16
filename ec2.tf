provider "aws" {
    region  =  "ap-south-1"
    profile  =  "nishu"
}
resource "tls_private_key" "mytaskkey"  {
   algorithm  =  "RSA"
 }

resource "aws_key_pair" "keypair"  {
    key_name  =  "mytaskkey"
    public_key  = tls_private_key.mytaskkey.public_key_openssh
  
    depends_on  =  [ 
               tls_private_key.mytaskkey
       ]
}
resource "aws_security_group" "mytask_sec_group" {
        name           =  "mytask_sec_group"
        description  =  "Allow SSH and HTTP"
        vpc_id  =  "vpc-04db8e67c7e69da1e"

        ingress { 
           description   =  "SSH"
           from_port     =  22
           to_port         =  22
           protocol       =  "tcp"
           cidr_blocks  =  [ "0.0.0.0/0"]
         }
        
         ingress {
            description   =  "HTTP"
            from_port     =  80
            to_port         =  80
            protocol        =  "tcp"
            cidr_blocks   =  [ "0.0.0.0/0" ]
         }
         egress {
             from_port  =  0
             to_port      =  0
             protocol    =  "-1"
             cidr_blocks  =  [ "0.0.0.0/0" ]
        }
       tags  =  {
           Name  =  "mytask_sec_group"
        }
}
resource "aws_instance"  "myinstan"  {
    ami   =  "ami-0447a12f28fddb066"
    instance_type  =  "t2.micro"
    key_name  =  aws_key_pair.keypair.key_name
    security_groups  =  [ "mytask_sec_group" ]
   provisioner  "remote-exec" {
              connection  {
                  agent   =  "false"
                  type     =  "ssh"
                  user     =  "ec2-user"
                  private_key  =  tls_private_key.mytaskkey.private_key_pem
                  host     =  aws_instance.myinstan.public_ip
          }
         inline  =  [
           "sudo  yum install httpd  php  git  -y",
           "sudo  systemctl  restart  httpd",
           "sudo systemctl  enable httpd",
         ]
  }
 
   tags  =  {
        Name = "mytaskos"
     }
}
output "az" {
       value=aws_instance.myinstan.availability_zone
}
output "pubip" {
       value=aws_instance.myinstan.public_ip
}



resource "aws_ebs_volume" "myebs" {
        availability_zone  =  aws_instance.myinstan.availability_zone
        size  =  1
        tags  =  {
            Name  =  "myebs1"
        }
}
resource "aws_volume_attachment"  "ebs_attachment1"  {
         device_name  =  "/dvd/sdd"
         volume_id  =  aws_ebs_volume.myebs.id
         instance_id  =  aws_instance.myinstan.id
         force_detach  =  true 
  }



resource  "null_resource"  "mounting" {
      depends_on = [
            aws_volume_attachment.ebs_attachment1,
      ]
      connection {
             type  =  "ssh"
             user  =  "ec2-user"
             private_key  =  tls_private_key.mytaskkey.private_key_pem
             host  =  aws_instance.myinstan.public_ip
       }
      provisioner  "remote-exec" {
             inline  =  [
                 "sudo  mkfs.ext4  /dev/xvdd",
                 "sudo mount /dev/xvdh  /var/www/html",
                 "sudo rm -rf /var/www/html/*",
                 "sudo git clone https://github.com/Nishantsingh70/terraform_aws.git    /var/www/html"
             ]
         }
    }

resource "aws_s3_bucket"  "mytaskbucket"  {
            bucket  =  "mybucket23433"
            acl  =  "private"
            region = "ap-south-1"
        versioning {
                       enabled  =  true
        }
       tags  =  {
           Name  =  "mytaskbucket23433" 
        }
}
resource "aws_s3_bucket_object"  "mytaskbucket_object"  {
         depends_on = [aws_s3_bucket.mytaskbucket , ]
          bucket  =  aws_s3_bucket.mytaskbucket.id
          key   =  "img.jpg"  
          source  =  "terraform_aws/img.jpg"
          acl  =  "public-read"
   }
output "Image"{
   value = "aws_s3_bucket_object.git_down"
}
resource "aws_cloudfront_distribution" "mytaskcloudfront" {
        origin {
                domain_name = "mybucket.s3.amazonaws.com"
                origin_id   = "S3-mybucket23433-id"
                custom_origin_config  {
                      http_port  =  80
                      https_port  =  80
                      origin_protocol_policy  =  "match-viewer"
                      origin_ssl_protocols  =  [ "TLSv1" , "TLSv1.1" , "TLSv1.2" ]
           }
}
enabled  =  true
default_cache_behavior {
            allowed_methods  =  ["DELETE" , "GET" , "HEAD" , "OPTIONS" , "PATCH" , "POST" , "PUT" ]
            cached_methods = ["GET" , "HEAD"]
            target_origin_id  =  "S3-mybucket23433-id"
        
            forwarded_values  {
                query_string  =  false
                 cookies {
                               forward = "none"
                 }
 }
viewer_protocol_policy  =  "allow-all"
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

   provisioner  "local-exec"  {
           command  =  "google-chrome ${aws_instance.myinstan.public_ip}"
   }
}