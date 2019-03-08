# Adjust vars for the AWS settings and region
# These VPCs, subnets, and gateways will be created as part of the demo
public_key_path = "~/.ssh/id_rsa.pub"
aws_region = "us-east-1"
key_name = "AWS-SSH-KEY-NAME"
aws_vpc_cidr = "10.10.0.0/16"
aws_external_subnet_cidr = "10.10.1.0/24"
aws_internal_subnet_cidr = "10.10.2.0/24"
aws_webserver1_subnet_cidr = "10.10.10.0/24"
aws_webserver2_subnet_cidr = "10.10.20.0/24"
chkp_instance_size = "c5.large"
ws_size = "t2.micro"
r53zone = "MYDNSNAME.INROUTE53"
externaldnshost = "cg-demo"
SICKey = "vpn12345"
AllowUploadDownload = "true"
pwd_hash = "$1$8SfURQQf$dXRtRJQX8cFPg23QTqv9T0"

my_user_data = <<-EOF
                #!/bin/bash
                clish -c 'set user admin shell /bin/bash' -s
                blink_config -s 'gateway_cluster_member=false&ftw_sic_key=vpn12345&upload_info=true&download_info=true&admin_hash="$1$8SfURAAf$dXRtRJQX8cFPg25NTqv9T0"'
                addr="$(ip addr show dev eth0 | awk "/inet/{print \$2; exit}" | cut -d / -f 1)"
                dynamic_objects -n LocalGateway -r "$addr" "$addr" -a
                clish -c 'add vpn tunnel 1 type numbered local 169.255.254.2 remote 169.255.254.1 peer ExternalGateway' -s
                clish -c 'set interface vpnt1 state on' -s
                clish -c 'set static-route 10.0.0.0/16 nexthop gateway logical vpnt1 on' -s
                clish -c 'set static-route 10.10.10.0/24 nexthop gateway address 10.10.2.1 on' -s
                clish -c 'set static-route 10.10.20.0/24 nexthop gateway address 10.10.2.1 on' -s
                EOF

ubuntu_user_data = <<-EOF
                    #!/bin/bash
                    until sudo apt-get update && sudo apt-get -y install apache2;do
                      sleep 1
                    done
                    until curl \
                      --output /var/www/html/CloudGuard.png \
                      --url https://www.checkpoint.com/wp-content/uploads/cloudguard-hero-image.png ; do
                       sleep 1
                    done
                    sudo chmod a+w /var/www/html/index.html
                    echo "<html><head><meta http-equiv=refresh content=2;'http://cg-demo.MYDNSNAME.INROUTE53/' /> </head><body><center><H1>" > /var/www/html/index.html
                    echo $HOSTNAME >> /var/www/html/index.html
                    echo "<BR><BR>Check Point CloudGuard Terraform Demo <BR><BR>Any Cloud, Any App, Unmatched Security<BR><BR>" >> /var/www/html/index.html
                    echo "<img src=\"/CloudGuard.png\" height=\"25%\">" >> /var/www/html/index.html
                    EOF
