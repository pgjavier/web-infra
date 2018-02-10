  The tasks consist in two git repositories, the actual one which contains all the necesary files to complete the built of the infrustructe and https://github.com/pgjavier/simple-web which coaints the website code.

  For this I have used AWS which setup is made by terraform and ansible to configure the instances, also the webservers are running with docker container. A part of that an instance of jenkins (master and slave) has been created to give the availability of CI, deploying the website code directly from github using webhooks.

  The infrustructe is compose by 1 customer facing loadbalancer and n instances of frontends, in this example I use 2. The necesary subnets, groups and rules have been set to accomplish this task. As it is a development environment the nodes have direct access to internet to facilitate the deployment of the infrastructure.

  In a production environment this would not be recommend and other tools like nexus (to store the docker images), or spacewalk (to have control of the packages) will be necessary.

  Prerequisites:
  In the computer executing this code requires the following package:
    - git
    - ansible
    - terraform

  Also it is need to setup AWS credentials in the ~/.aws/credentials file.

  In variables.tf you will need to add the path to they Public key that you want to use to connect to AWS.

    variable "public_key_path" {
    description = "Enter the path to the SSH Public Key to add to AWS."
    default = "~/.ssh/terraform.pub"
  }

  For checking to be able to conect to the slave, you need to add a private key to playbooks/roles/jenkins/files/id_rsa. It is been removed for security reasons.

  Firstly you need to clone the actual repository to your local computer.

    git clone https://github.com/pgjavier/web-infra.git

  In order to run terraform you will to download it from https://www.terraform.io/downloads.html
  Go into the directory and run the following command to initiate terraform:

    terraform init

  You can now validate the terraform files

    terraform validate

  After that we will create an excecution plan

    terraform plan

  Finally after checking the excecution plan we will apply the configuration

    terraform apply

  Terraform will trigger ansible in order to configure the instances once they are running.

  Due to the delays of the starting the aws instances I decided to removed the code that executes ansible from terraform as it was failing sometimes, even adding some mechanims to try to avoid it. It needs to be trigger in this way:

    ansible-playbook -u centos --private-key 'key/id_rsa.pub' playbooks/site.yml

  The initial configuration of jekins needs to be manually done such as adding credentials. Also the configuration of webhooks in github is being done manually. With an own git server this part could be also automate.

  If in any moment it is need to lunch ansible configuration again, it can be done executing the following playbook:

    ansible-playbook -u centos --private-key 'key/id_rsa.pub' playbooks/site.yml

  To manually deploy the website code you can run:

    ansible-playbook -u centos --private-key 'key/id_rsa.pub' playbooks/website-deploy.yml

  In order to avoid down time to the customers the deployment of the code is setup to be done in serie, in this case doing first the 50% of the nodes before continuing with the rest.

  The site can be access from:

    http://elb-public-frontend-642838251.us-east-2.elb.amazonaws.com/
