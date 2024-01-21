#!/bin/bash
# https://github.com/tradichel/SecurityMetricsAutomation
# awsdepoy/job/run.sh
# author: @tradichel @2ndsightlab
# description: Script that runs when container executes
##############################################################
 
#include files
source shared/validate.sh
source shared/functions.sh
source resources/ssm/parameter/parameter_functions.sh

#configure job role CLI profile
	parameters="$1"
	profile=$(get_container_parameter_value $parameters "profile")
	access_key=$(get_container_parameter_value $parameters "accesskey")
	secret_key=$(get_container_parameter_value $parameters "secretaccesskey")
	session_token=$(get_container_parameter_value $parameters "sessiontoken")
	region=$(get_container_parameter_value $parameters "region")
	job_config_ssm_parameter=$(get_container_parameter_value $parameters "jobconfig")

	s="job/run.sh"
	validate_set $s "profile" $profile
	validate_set $s "access_key" $access_key
	validate_set $s "secret_key" $secret_key
	validate_set $s "session_token" $session_token
  validate_set $s "region" $region
  
  echo "### Creating profile for $profile ###"
  aws configure set aws_access_key_id $access_key --profile $profile
  aws configure set aws_secret_access_key $secret_key --profile $profile
  aws configure set aws_session_token $session_token --profile $profile
  aws configure set region $region --profile $profile
  aws configure set output "json" --profile $profile

  #clear variables
  access_key=""
  secret_key=""
  session_token=""

  echo "### Created AWS CLI profile in container for: $profile ###"
	aws sts get-caller-identity --profile $profile

#execute the job
	echo "### execute the job - the execution script has container specific execution code ###"
	./execute.sh $profile $job_config_ssm_parameter



