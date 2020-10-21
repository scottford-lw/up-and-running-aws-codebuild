<img src="https://techally-content.s3-us-west-1.amazonaws.com/public-content/lacework_logo_full.png" width="600">

# Up and Running with Lacework and AWS Code Build
This repo contains example code for the Up and Running with Lacework and AWS CodeBuild as seen
on the Lacework blog, Lacework YouTube channel, and for the AWS Howdy Partner! series on 
TwitchTV (October 2020).

This code walks you through how to build an AMI factory with HashiCorp Packer, AWS CodeBuild,
and adds security testing with Lacework's host vulnerability scanning. 

### Requirements 
Before you begin you will need the following:

- GitHub Account
- An AWS Account with permissions to launch services
- Lacework Account (If you want to add vulnerability scanning)

If you are interested in trying out Lacework click [here](https://lacework.zoom.us/webinar/register/2816011682181/WN_RPlaxEiXRoWyRiBjFop6tQ)

## Walkthrough
The following steps will walk you through setting up AWS CodeBuild to build an AMI in `us-east-1`

### Fork The Example Repo
Make sure you are signed into your GitHub account then **Fork** this repository to your own GitHub Org

### Setup AWS CodeBuild
1. Login to the AWS Console and navigate to AWS CodeBuild, or click the following link to go there directly...

   https://console.aws.amazon.com/codesuite/codebuild/projects?region=us-east-1

2. Click the **Create build project**
3. For the **Project Name** use "AMI_Builder"
4. For the **Source** section, choose "GitHub" as the source. Connect to GitHub using **OAuth** then authorize CodeBuild to access your personal GitHub org (You can revoke this at any time).  For the **Repository URL** paste link to the example you forked in the previous step. ( _i.e. `https://github.com/<YOUR_GH_USER>/up-and-running-aws-codebuild`_)

<img src="https://techally-artifacts.s3-us-west-2.amazonaws.com/up-and-running/github_oauth.gif">

5. For the **Environment** section use the default selection of **Managed Image** and choose "Amazon Linux 2" for the operating system. For **Runtime(s)** choose "Standard", and for **Image** choose "aws/codebuild/amazonlinux2-x86_64-standard:3.0". The **Role Name** should default to "codebuild-AMI_Builder-service-role". Expand the **Additional configuration** section and scroll down to **Environment variables** and add a "Plaintext" variable of "AWS_REGION" with a value of "us-east-1"

<img src="https://techally-artifacts.s3-us-west-2.amazonaws.com/up-and-running/environment.gif">

6. For the remaining sections leave everything default for now and then click **Create Build Project**

## Update IAM Role policy for Packer
In the previous step we created an IAM role for AWS CodeBuild called "codebuild-AMI_Builder-service-role". That Role has basic policy that provides the CodeBuild project to required resources. Packer however needs certain permissions to be able to make API calls, so we need to update the IAM Policy before we can build. 

1. Open IAM in the AWS Console
2. On the Right hand side click on **Roles** and search for "codebuild-AMI_Builder-service-role"
3. Click on the Policy (should be "CodeBuildBasePolicy-AMI_Builder-us-east-1")
4. Click **Edit Policy** then choose the **JSON** editor
5. Scroll down to line 50 and add a "," after the "}" then paste the following snippet of JSON

    ```json
    {
      "Effect": "Allow",
      "Action": [
          "ec2:AttachVolume",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:CopyImage",
          "ec2:CreateImage",
          "ec2:CreateKeypair",
          "ec2:CreateSecurityGroup",
          "ec2:CreateSnapshot",
          "ec2:CreateTags",
          "ec2:CreateVolume",
          "ec2:DeleteKeyPair",
          "ec2:DeleteSecurityGroup",
          "ec2:DeleteSnapshot",
          "ec2:DeleteVolume",
          "ec2:DeregisterImage",
          "ec2:DescribeImageAttribute",
          "ec2:DescribeImages",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceStatus",
          "ec2:DescribeRegions",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSnapshots",
          "ec2:DescribeSubnets",
          "ec2:DescribeTags",
          "ec2:DescribeVolumes",
          "ec2:DetachVolume",
          "ec2:GetPasswordData",
          "ec2:ModifyImageAttribute",
          "ec2:ModifyInstanceAttribute",
          "ec2:ModifySnapshotAttribute",
          "ec2:RegisterImage",
          "ec2:RunInstances",
          "ec2:StopInstances",
          "ec2:TerminateInstances"
      ],
      "Resource": "*"
    }
    ```
6. Click **Review Policy**
7. Click **Save changes**


## First AMI Build with Packer and AWS CodeBuild
In this section we are going to kick off the first build of a base image with CodeBuild just to test that images are publishing successfully to AWS. 

1. Open the AWS Console and Navigate to **CodeBuild**
2. Click on **Build projects** then click on the **AMI_Builder** project
3. Click **Start Build**
4. You can leave everything default and click on **Start Build** again
5. Click **Tail Logs** to watch the build (Build may take between 5-10min)
<img src="https://techally-artifacts.s3-us-west-2.amazonaws.com/up-and-running/tail_logs.png">
  
  Once the build completes you will see a message `HashiCorp Packer build completed on <DATE>`

Optionally, you can also navigate to **EC2 -> Images/AMIs** and search for "Packer" to see the built image

## Adding Lacework Vulnerability Scanning to the build
Now that AMIs are publishing successfully we can add some security to the build process and validate that our images are free of vulnerabilities. 

In the build process we are already using the `shell` provisioner of Packer to run a `yum update -y` which will update all of the packages on the host.

Now we are going to use the Lacework CLI to generate a package manifest (a list of installed packages and their version) and submit that to Lacework to scan for vulnerabilities. After returning the results we will remove the Lacework CLI from the build.

### Create API Keys
In order to authenticate with Lacework's APIs for a vulnerability scan you will need to create an API Key and Secret.

<img src="https://techally-artifacts.s3-us-west-2.amazonaws.com/up-and-running/api_key.gif">

1. Login to the Lacework console and click on **Settings** followed by **API Keys** followed by **CREATE NEW API KEY**
2. Give the API key a name the click **Save**
3. Click the green **Download** button next to the **Enabled** slider to download a `JSON` file with your key and secret

### Store API Key in AWS System Manager Parameter Store
The API Key for Lacework should be treated securely and never shared out. AWS CodeBuild supports the ability to pull secrets from AWS Systems Manager Parameter store which is free! We will use that to store the parameters for integrating with Lacework. 

We need to configure the following parameters:

```
LW_ACCOUNT (Plaintext): "Your Lacework Account"
LW_API_KEY (Plaintext): "Your Lacework API Key ID"
LW_API_SECRET (SecureString): "Your Lacework API secret"
```

1. Login to the AWS Console and navigate to AWS Systems Manager
2. On the left hand side click on **Parameter Store**
3. Click **Create Parameter**
4. For the **Name** use "LW_ACCOUNT", for the **Type** use "String" and for the **Value** use the name of your Lacework account
5. Click **Create Parameter** to store the parameter
6. Click **Create Parameter**
7. For the **Name** use "LW_API_KEY", for the **Type** use "String" and for the **Value** use the API_KEY_ID from the `JSON` you downloaded in the previous step
8. Click **Create Parameter** to store the parameter
9. Click **Create Parameter**
7. For the **Name** use "LW_API_SECRET", for the **Type** use "SecureString" and for the **Value** use the API_KEY_SECRET from the `JSON` you downloaded in the previous step
8. Click **Create Parameter** to store the parameter

<img src="https://techally-artifacts.s3-us-west-2.amazonaws.com/up-and-running/params.png">

### Update IAM Policy for SSM Access
In order for CodeBuild to pull parameters from the Parameter store we need to update the IAM Policy to provide access. 

2. On the Right hand side click on **Roles** and search for "codebuild-AMI_Builder-service-role"
3. Click on the Policy (should be "CodeBuildBasePolicy-AMI_Builder-us-east-1")
4. Click **Edit Policy** then choose the **JSON** editor
5. Update the policy to include `"ssm:GetParameters",` policy should look like this...

    ```json
    {
      "Effect": "Allow",
      "Action": [
          "ssm:GetParameters",
          "ec2:AttachVolume",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:CopyImage",
          "ec2:CreateImage",
          "ec2:CreateKeypair",
          "ec2:CreateSecurityGroup",
          "ec2:CreateSnapshot",
          "ec2:CreateTags",
          "ec2:CreateVolume",
          "ec2:DeleteKeyPair",
          "ec2:DeleteSecurityGroup",
          "ec2:DeleteSnapshot",
          "ec2:DeleteVolume",
          "ec2:DeregisterImage",
          "ec2:DescribeImageAttribute",
          "ec2:DescribeImages",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceStatus",
          "ec2:DescribeRegions",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSnapshots",
          "ec2:DescribeSubnets",
          "ec2:DescribeTags",
          "ec2:DescribeVolumes",
          "ec2:DetachVolume",
          "ec2:GetPasswordData",
          "ec2:ModifyImageAttribute",
          "ec2:ModifyInstanceAttribute",
          "ec2:ModifySnapshotAttribute",
          "ec2:RegisterImage",
          "ec2:RunInstances",
          "ec2:StopInstances",
          "ec2:TerminateInstances"
      ],
      "Resource": "*"
    }
    ```
6. Click **Review Policy**
7. Click **Save changes** 

### Update the buildspec.yml to pull parameters
Now we need to update our `buildspec.yml` to pull in parameters and set environment variables

1. On your local workstation clone the example git repo you forked in the first step
   
   `$ git clone https://github.com/<your_user>/up-and-running-aws-codebuild.git`

2. Change directories into `up-and-running-aws-codebuild`
3. Open `buildspec.yml` in and editor of choice to the following version

```
---
version: 0.2
env:
  parameter-store:
    LW_ACCOUNT: "LW_ACCOUNT"
    LW_API_KEY: "LW_API_KEY"
    LW_API_SECRET: "LW_API_SECRET"
    

phases:
  pre_build:
    commands:
      - echo "Installing HashiCorp Packer..."
      - curl -qL -o packer.zip https://releases.hashicorp.com/packer/0.12.3/packer_0.12.3_linux_amd64.zip && unzip packer.zip
      - echo "Installing jq..."
      - curl -qL -o jq https://stedolan.github.io/jq/download/linux64/jq && chmod +x ./jq
      - echo "Validating amazon_linux_packer_template.json"
      - ./packer validate amazon_linux_packer_template.json
  build:
    commands:
      ### HashiCorp Packer cannot currently obtain the AWS CodeBuild-assigned role and its credentials
      ### Manually capture and configure the AWS CLI to provide HashiCorp Packer with AWS credentials
      ### More info here: https://github.com/mitchellh/packer/issues/4279
      - echo "Configuring AWS credentials"
      - curl -qL -o aws_credentials.json http://169.254.170.2/$AWS_CONTAINER_CREDENTIALS_RELATIVE_URI > aws_credentials.json
      - aws configure set region $AWS_REGION
      - aws configure set aws_access_key_id `./jq -r '.AccessKeyId' aws_credentials.json`
      - aws configure set aws_secret_access_key `./jq -r '.SecretAccessKey' aws_credentials.json`
      - aws configure set aws_session_token `./jq -r '.Token' aws_credentials.json`
      - echo "Building HashiCorp Packer template, amazon_linux_packer_template.json"
      - ./packer build amazon_linux_packer_template.json
  post_build:
    commands:
      - echo "HashiCorp Packer build completed on `date`"
```

The `env` section at the top will set ENVIRONMENT VARIABLES that we need in the build process to scan the host for vulnerabilities

#### Commit and Push changes
Yes, pushing to `master` is not a good idea but for this exercise and in the interest of time we are going to do just that..

```
$ git add .
$ git commit 'updating buildspec with param store'
$ git push origin master
```

New buildspec should be ready to go to pull in params

### Update Packer Template to test for vulnerabilities
In order to test our build for vulnerabilities we are going to use the Lacework CLI which will generate a package manifest and submit it to Lacework to scan the list of packages for vulnerabilities and return the results to AWS CodeBuild. 

We are going to update our Packer template to leverage the ENV variables from the previous step so the Lacework CLI can authenticate with your Lacework account. The packer build will place a script on the host at build that installs the Lacework CLI, and then executes a `lacework vulnerability host scan-pkg-manifest --local` command which generates the package manifest, and submits it to Lacework to scan. 

Once the results are returned we will uninstall the Lacework CLI from the host

1. On your local workstation, open the `amazon_linux_packer_template.json` Packer template in an EDITOR of choice
2. Update the packer template with the following contents:

```
{
  "variables": {
      "aws_region": "{{env `AWS_REGION`}}",
      "aws_ami_name": "amazon_linux_packer_{{isotime \"20060102150405\"}}",
      "lw_account": "{{env `LW_ACCOUNT`}}",
      "lw_api_key": "{{env `LW_API_KEY`}}",
      "lw_api_secret": "{{env `LW_API_SECRET`}}"
  },

  "builders": [{
      "type": "amazon-ebs",
      "region": "{{user `aws_region`}}",
      "instance_type": "t2.micro",
      "ssh_username": "ec2-user",
      "ami_name": "{{user `aws_ami_name`}}",
      "ami_description": "Customized Amazon Linux - Generated by Packer",
      "associate_public_ip_address": "true",
      "source_ami_filter": {
          "filters": {
              "virtualization-type": "hvm",
              "name": "amzn-ami*-ebs",
              "root-device-type": "ebs"
          },
          "owners": ["137112412989", "591542846629", "801119661308", "102837901569", "013907871322", "206029621532", "286198878708", "443319210888"],
          "most_recent": true
      }
  }],

  "provisioners": [
    {
        "type": "file",
        "source": "files/lacework-cli.sh",
        "destination": "/tmp/lacework-cli.sh"
    },
    {
        "type": "shell",
        "environment_vars": [
            "LW_ACCOUNT={{user `lw_account`}}",
            "LW_API_KEY={{user `lw_api_key`}}",
            "LW_API_SECRET={{user `lw_api_secret`}}"
        ],
        "inline": [
            "sudo yum update -y",
            "source /tmp/lacework-cli.sh",
            "rm /tmp/lacework-cli.sh",
            "echo \"Removing Lacework CLI from base image...\"",
            "sudo rm -rf /usr/local/bin/lacework"
        ]
    }
  ]
}
```
3. Save the file

#### Commit and Push changes
Yes, pushing to `master` is not a good idea but for this exercise and in the interest of time we are going to do just that again..

```
$ git add .
$ git commit 'updating packer template to test for vulnerabilities'
$ git push origin master
```

New packer template should be ready to go!

## AMI Build with Packer and AWS CodeBuild and vulnerability scanning with Lacework!
We are now ready to add vulnerability scanning to our build with Lacework 

1. Open the AWS Console and Navigate to **CodeBuild**
2. Click on **Build projects** then click on the **AMI_Builder** project
3. Click **Start Build**
4. You can leave everything default and click on **Start Build** again
5. Click **Tail Logs** to watch the build (Build may take between 5-10min)
<img src="https://techally-artifacts.s3-us-west-2.amazonaws.com/up-and-running/tail_logs.png">

6. This time around you should see the results of the scan...

```
amazon-ebs: ‘lacework-cli-linux-amd64/lacework’ -> ‘/usr/local/bin/lacework’
    amazon-ebs: info: No menu item `Verifying installed Lacework CLI version' in node `(dir)Top'.
    amazon-ebs: lacework v0.2.6 (sha:7bee20719f1cf4dea1637f03a950d905266d4f10) (time:20201013210921)
    amazon-ebs: | Checking available updates... ································································/ Checking available updates... ································································--> install: The Lacework CLI has been successfully installed.
    amazon-ebs: #######################################################
    amazon-ebs: #                                                     #
    amazon-ebs: # RUNNING LACEWORK VULNERABILITY SCAN OF LOCALHOST... #
    amazon-ebs: #                                                     #
    amazon-ebs: #######################################################
    amazon-ebs:
    amazon-ebs: Great news! The localhost has no vulnerabilities... (time for 🌮 )
    amazon-ebs:
    amazon-ebs: #######################################################
    amazon-ebs: #                                                     #
    amazon-ebs: # LACEWORK VULNERABILITY SCAN COMPLETE!               #
    amazon-ebs: #                                                     #
    amazon-ebs: #######################################################
    amazon-ebs: Removing Lacework CLI from base image...
==> amazon-ebs: Stopping the source instance...
==> amazon-ebs: Waiting for the instance to stop...
```

Great new.s..NO VULNERABILITIES! Time for Tacos!!!

