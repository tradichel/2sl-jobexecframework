#!/bin/bash
# https://github.com/tradichel/SecurityMetricsAutomation
# awsdepoy/job/run.sh
# author: @tradichel @2ndsightlab
# description: Script that runs when container executes
##############################################################
 
#include files
source shared/validate.sh

#global PROFILE value used by aws jobs
PROFILE=""
JOB_CONFIG_SSM_PARAMETER=""

get_container_parameter_value(){
  local params="$1"
  local pname="$2"

  local func=${FUNCNAME[0]}
  validate_set $func 'params' $params
  validate_set $func 'pname' $pname

  for p in ${params//,/ }
  do
    local n=$(echo $p | cut -d "=" -f1)
    if [ "$n" == "$pname" ]; then
      local value=$(echo $p | sed 's/,//g' | cut -d "=" -f2)
      #if value starts with [ get everyting to end because it's the parameter list to forward; remove the ]
      if [[ $value == [* ]]; then
        local value=$(echo $params | cut -d '[' -f2 | sed 's/]//g')
      fi
      echo $value
      exit
    fi
  done
}

main(){
	parameters="$1"

	PROFILE=$(get_container_parameter_value $parameters "profile")
  JOB_CONFIG_SSM_PARAMETER=$(get_container_parameter_value $parameters "jobconfig")

	local access_key=$(get_container_parameter_value $parameters "accesskey")
	local secret_key=$(get_container_parameter_value $parameters "secretaccesskey")
	local session_token=$(get_container_parameter_value $parameters "sessiontoken")
  local region=$(get_container_parameter_value $parameters "region")
	  	
	echo "### Validate parameters passed to job ###"
	s="job/run.sh"
	validate_set $s "PROFILE" $PROFILE
	validate_set $s "access_key" $access_key
	validate_set $s "secret_key" $secret_key
	validate_set $s "session_token" $session_token
  validate_set $s "region" $region
	
	if [ "$job_config_ssm_paramter" != "" ]; then
		validate_job_param_name $JOB_CONFIG_SSM_PARAMETER
	fi
  
  echo "### Creating PROFILE for $PROFILE ###"
  aws configure set aws_access_key_id $access_key --profile $PROFILE
  aws configure set aws_secret_access_key $secret_key --profile $PROFILE
  aws configure set aws_session_token $session_token --profile $PROFILE
  aws configure set region $region --profile $PROFILE
  aws configure set output "json" --profile $PROFILE

  #clear variables
  access_key=""
  secret_key=""
  session_token=""

  echo "### Created AWS CLI PROFILE in container for: $PROFILE ###"
	aws sts get-caller-identity --profile $PROFILE

  #execute the job - using source to use global parameters in execute.sh
	echo "### Call execute.sh for $JOB_CONFIG_SSM_PARAMETER with $PROFILE ###"
	source execute.sh
	
}

echo "Executing job/aws/run.sh"
main $1
