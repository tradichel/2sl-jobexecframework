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

  #may have optional parameter
  #need to check if value is set outside of this function because bash

}

main(){
  #configure job role CLI PROFILE
	parameters="$1"

	PROFILE=$(get_container_parameter_value $parameters "PROFILE")
	local access_key=$(get_container_parameter_value $parameters "accesskey")
	local secret_key=$(get_container_parameter_value $parameters "secretaccesskey")
	local session_token=$(get_container_parameter_value $parameters "sessiontoken")
  local region=$(get_container_parameter_value $parameters "region")
	local job_config_ssm_parameter=$(get_container_parameter_value $parameters "jobconfig")
  	
	s="job/run.sh"
	validate_set $s "PROFILE" $PROFILE
	validate_set $s "access_key" $access_key
	validate_set $s "secret_key" $secret_key
	validate_set $s "session_token" $session_token
  validate_set $s "region" $region
	
	if [ "$job_config_ssm_paramter" != "" ]; then
		validate_job_param_name $job_config_ssm_parameter
	fi
  
  echo "### Creating PROFILE for $PROFILE ###"
  aws configure set aws_access_key_id $access_key --PROFILE $PROFILE
  aws configure set aws_secret_access_key $secret_key --PROFILE $PROFILE
  aws configure set aws_session_token $session_token --PROFILE $PROFILE
  aws configure set region $region --PROFILE $PROFILE
  aws configure set output "json" --PROFILE $PROFILE

  #clear variables
  access_key=""
  secret_key=""
  session_token=""

  echo "### Created AWS CLI PROFILE in container for: $PROFILE ###"
	aws sts get-caller-identity --PROFILE $PROFILE

  #execute the job
	echo "### execute the job - the execution script has container specific execution code ###"
	./execute.sh $PROFILE $job_config_ssm_parameter
	
}

main $1
