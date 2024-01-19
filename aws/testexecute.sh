#!/bin/bash -e
# https://github.com/tradichel/SecurityMetricsAutomation
# awsdeploy/testexecute.sh
# author: @tradichel @2ndsightlab
# description: Test code in container outside an EC2 instance
##############################################################
source container/shared/validate.sh
source container/shared/functions.sh
source container/resources/organizations/organization/organization_functions.sh 
source container/resources/organizations/account/account_functions.sh 

#used in validation routine to report the code source
#that produced a validation error
s="testexecute.sh"

echo "********************************************"
echo "Enter job to execute. This step assumes you"
echo "Have cloned the relevant repositories to the"
echo "same directory and all job directories start"
echo "with 2sl-job-."
echo "********************************************"
ls ../../ | grep "2sl-job-" | sed 's/2sl-job-//'
read job

validate_set $s "job" $job

echo "********************************************"
echo "Set session length for temporary credentials"
echo "********************************************"
#minimum 900 secods or 15 minutes
max_session_duration_seconds=900
echo "Session length is $max_session_duration_seconds. Override? (y)"
read override
if [ "$override" == "y" ]; then
 	echo "Enter seconds"; read seconds
	validate_numeric $seconds
	max_session_duration_seconds=$seconds
fi

echo "********************************************"
echo "Build image if files changed"
echo "********************************************"
echo "Build? (y)"; read build
if [ "$build" == "y" ]; then ./scripts/build.sh $job;fi
echo "********************************************"
echo "Build complete"
echo "********************************************"
echo "********************************************"
echo "Optionally Push and Pull container to ECR"
echo "********************************************"

echo "Push to and pull to validate correct image is in ECR? (y)"; read push
if [ "$push" == "y" ]; then 
	echo "********************************************"
	echo "********** Push container to ECR ***********"
	echo "********************************************"
	./scripts/push.sh $job; 
	
	image="awsdeploy"
	echo "********************************************"
	echo " Pull image back down (testing push worked correctly)"
	echo "********************************************"
	source scripts/pull.sh $job
fi

echo "********************************************"
echo "Enter the AWS CLI profile that similates the "
echo "ec2 instance role. The role must have permission "
echo "to read the secret that contains the user credentails"
echo "and the job config SSM parameters which I require to"
echo "exist in the same accout as the EC2 instance"
echo "that is executing the job. The EC2 instance"
echo "and all that it requires should be in the same"
echo "account to limit attack surface and complexity."
echo "The jobs themselves can perform cross-account actions."
echo "********************************************"
echo "Enter AWS CLI profile that simulates EC2 instance role. "
echo "Press <enter> for defaullt profile name: ec2jobrole."
echo "Enter L to list all profiles:"
read ec2rolename
if [ "$ec2rolename" == "L" ]; then aws configure list-profiles | sort
	echo "Enter profile:"; read ec2rolename;
fi
if [ "$ec2rolename" == "" ]; then ec2rolename="ec2jobrole"; fi
validate_set $s "ec2rolename" $ec2rolename

region=$(get_region_for_profile $ec2rolename)
ec2account=$(get_account_for_profile $ec2rolename)
validate_set $s "region" $region
validate_set $s "ec2account" $ec2account
echo "EC2 region: $region"
echo "EC2 account: $ec2account"

echo "********************************************"
echo "Enter job name to execute. Parse the role"
echo "used to execute the job and the resource"
echo "used in the session name out of the job"
echo "configuration parameter name."
echo "********************************************"
echo -e "\nAvailable jobs in in this account:"
aws ssm describe-parameters --profile $ec2rolename --query Parameters[*].Name --output text | grep job
echo "Enter job:"
read job_parameter

jobrole=$(echo $job_parameter | cut -d "/" -f4)
echo "Job Role: $jobrole"
validate_set $s "jobrole" $jobrole

echo "********************************************"
echo "Enter the username that owns the credentials"
echo "used to assume the role that executes the job."
echo -e "\nThe credetials must be in a secret in the same"
echo "account as the EC2 instance and role that runs"
echo "the job"
echo -e "\nThe user has a virtual MFA device associated"
echo "with the credentials so they can pass in a"
echo "token to the job to assume the role with MFA."
echo "********************************************"
echo "Available secrets:"
aws secretsmanager list-secrets --output text --profile $ec2rolename --query "SecretList[*].Name"
echo "enter secret name matching username associated with credentials used to run the job:"
read username
validate_set $s "username" $username

echo "********************************************"
echo "Get Credentials from secrets manager in account $ec2account for $username"
echo "********************************************"
secret=$(aws secretsmanager get-secret-value \
  --secret-id 'arn:aws:secretsmanager:'$region':'$ec2account':secret:'$username \
  --query SecretString --output text --profile $ec2rolename)
validate_set $s "Access key and secret key in secret $username" $secret
access_key_id=$(echo $secret | jq -r ".aws_access_key_id")
secret_key=$(echo $secret | jq -r ".aws_secret_key")
mfaaccount=$(echo $secret | jq -r ".user_account_id")
validate_set $s "access_key_id in secret: $username." $access_key_id
validate_set $s "secret_key in secret: $username." $secret_key
validate_set $s "user_account_id in secret: $username." $mfaaccount

echo "********************************************"
echo " Calculate the mfa serial for use in AWS CLI Profiles"
echo "********************************************"
#due to policies MFA will only work if MFA device name matches username
mfa_serial="arn:aws:iam::$mfaaccount:mfa/$username"
validate_set $s "mfa_serial" $mfa_serial
echo "MFA Serial: $mfa_serial"

echo "********************************************"
echo "Configure CLI profile on EC2 instance for $username"
echo "with credentails from secrets manager."
echo "Cannot enforce MFA with long term dev credentials."
echo "********************************************"
configure_cli_profile \
	$username \
  $access_key_id \
  $secret_key \
  $region \
	$mfa_serial

echo "********************************************"
echo "Get an MFA token to assume jobrole: $jobrole"
echo "with CLI profile for user: $username"
echo "********************************************"
code=""
while [ "$code" == "" ]; do
	echo "Enter MFA code for $mfa_serial (crtl-C to exit):"; read -s code
done

sessionname=$(echo $job_parameter | sed 's|/|-|g')
sessionname=$(echo $username$sessionname)
sessionname=$(echo "${sessionname:0:64}")
echo "********************************************"
echo "Use profile to get short term credentials for session: $sessionname"
echo "with mfa_serial: $mfa_serial"
echo "********************************************"
creds=$(aws sts assume-role --token-code $code \
  --serial-number $mfa_serial \
  --role-session-name $sessionname \
  --role-arn 'arn:aws:iam::'$mfaaccount':role/'$jobrole \
  --profile $username \
  --region $region \
	--duration-seconds $max_session_duration_seconds)

accesskeyid="$(echo $creds | jq -r ".Credentials.AccessKeyId")"
secretaccesskey="$(echo $creds | jq -r ".Credentials.SecretAccessKey")"
sessiontoken="$(echo $creds | jq -r ".Credentials.SessionToken")"

echo "********************************************"
echo "Pass credentials to container"
echo "********************************************"
parameters="\
	rolename=$jobrole,\
	accesskey=$accesskeyid,\
	secretaccesskey=$secretaccesskey,\
	sessiontoken=$sessiontoken,\
	region=$region,\
	jobconfig=$job_parameter"

#remove any spaces so the parameter list is treated as a single argument passed to the container
parameters=$(echo $parameters | sed 's/ //g')

echo "********************************************"
echo "Run the container $image and execute the job $job_parameter"
echo "********************************************"
docker run $job $parameters



