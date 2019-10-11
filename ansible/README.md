# Deploy webserver using Ansible 

## Introduction
  The webserver IP is not static so Ansible need to detect webserver IP on the fly base on tag and add_host to ansible memory during running with role add_webserver_to_inventory_memory. The database password had been generated base on Ansible module aws_ssm. If using Ansible, we should not use shell ```aws ssm get-parameter <parameter-name> --with-decryption``` to get parameter since we have module aws_ssm. Then, Ansible use roles configure-webserver run on webserver host to deploy.
  
  The webserver will be deployed a Django app on virtual env and expose to port 80

## How to run

 There's a Makefile:
```
[root@puppet ansible]# cat Makefile 
env ?= stg
aws_profile ?= development
project ?= gfg
aws_region ?= ap-southeast-1
aws_domain ?= vdevops.io

configure-webserver-gfg:	
	AWS_PROFILE=${aws_profile} ansible-playbook configure-webserver-gfg.yaml -e project=${project} -e env=${env} -e aws_profile=${aws_profile} -e aws_region=${aws_region} -e aws_domain=${aws_domain}
```
 
 Running command: 
 [root@puppet ansible]# make configure-webserver-gfg aws_profile=development project=gfg env=stg aws_region=ap-southeast-1





