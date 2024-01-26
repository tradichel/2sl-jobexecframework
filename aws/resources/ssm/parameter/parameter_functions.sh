#!/bin/bash -e
# https://github.com/tradichel/SecurityMetricsAutomation/
# awsdeploy/resources/ssm/parameter/parameter_functions.sh
# author: @teriradichel @2ndsightlab
# description: Functions for AWS::SSM::Parameter
# and CLI scripts to deploy secure string parameters
##############################################################
source shared/functions.sh

#depoy with cloudformation
deploy_ssm_parameter(){

  ssm_name="$1"
  ssm_value="$2"

	echo "Parameters deployed via CloudFormation will be unencrypted"

  func=${FUNCNAME[0]}
  validate_set $func 'ssm_name' "$ssm_name"
 
 	cat="ssm"
	resourcetype='parameter'
  parameters=$(add_parameter "cfparamName" $ssm_name)
  parameters=$(add_parameter "ValueParam" $ssm_value $parameters)

  deploy_stack $name $cat $resourcetype $parameters

}

ssm_parameter_exists(){
	ssm_name="$1"
 
  validate_set "${FUNCNAME[0]}" "ssm_name" "$ssm_name"

	v=$(aws ssm describe-parameters --filters "Key=Name,Values=$ssm_name" --profile $profile)	
	t=$(echo $v | jq '.Parameters | length')
	if [[ $t == 0 ]]; then
		echo "false"
	else
		echo "true"
	fi

}

get_ssm_parameter_job_config() {
  ssm_name="$1"

  validate_set "${FUNCNAME[0]}" "ssm_name" $ssm_name

  validate_starts_with $ssm_name "/job/"
  jobconfig=$(get_ssm_parameter_value $ssm_name)
  validate_set "${FUNCNAME[0]}" "jobconfig" $jobconfig

  echo $jobconfig
}

get_ssm_parameter_value(){
  ssm_name="$1"

  func=${FUNCNAME[0]}
  validate_set $func "name" $ssm_name

	v=""
	exists=$(ssm_parameter_exists $ssm_name)
	if [ "$exists" == "true" ]; then
  	v=$(aws ssm get-parameter --name $ssm_name --with-decryption --query "Parameter.Value" --output text --profile $profile)
  fi
	echo $v
}

set_ssm_parameter_value(){
  ssm_name="$1"
  ssm_value="$2"
	kmskeyid="$3"
	tier="$4"

	#secure string doesn't work with 
	#cloudformation at the time I wrote
	#these scripts - default to standard,
	#secure string which is encrypted with 
	#the AWS managed KMS key
	
  if [ "$tier" == "" ]; then tier="Standard"; fi
 	parmtype='SecureString'

  func=${FUNCNAME[0]}
  validate_set $func "ssm_name" $ssm_name
  validate_set $func "ssm_value" $ssm_value

	ssm_name=$ssm_name

	if [ "$kmskeyid" != "" ]; then
		echo "aws ssm put-parameter --name $ssm_name --key-id $kmskeyid \
    	--value $ssm_value --tier $tier --type $parmtype --profile $profile"
  	aws ssm put-parameter --name $ssm_name --overwrite --key-id $kmskeyid --value $ssm_value \
			 --tier $tier --type $parmtype --profile $profile
	else
    echo "aws ssm put-parameter --name $ssm_name \
      --value $ssm_value --tier $tier --type $parmtype --profile $profile"
    aws ssm put-parameter --name $ssm_name --overwrite --value $ssm_value \
       --tier $tier --type $parmtype --profile $profile
	fi
}

set_ssm_parameter_job_config(){
  ssm_name="$1"
  kmskeyid="$2"
  tier="$2"

  #secure string doesn't work with 
  #cloudformation at the time I wrote
  #these scripts - default to standard,
  #secure string which is encrypted with 
  #the AWS managed KMS key

  if [ "$tier" == "" ]; then tier="Standard"; fi
  parmtype='SecureString'

  func=${FUNCNAME[0]}
  validate_set $func "ssm_name" "$ssm_name"

	if [ "$profile" != "" ]; then useprofile=" --profile $profile"; fi

  if [ "$kmskeyid" != "" ]; then
    echo "aws ssm put-parameter --name $ssm_name --overwrite --key-id $kmskeyid --value file://.$ssm_name \
       --tier $tier --type $parmtype $useprofile"
    aws ssm put-parameter --name $ssm_name --overwrite --key-id $kmskeyid --value file://.$ssm_name \
       --tier $tier --type $parmtype $useprofile
  else
    echo "aws ssm put-parameter --name $ssm_name --overwrite --value file://.$ssm_name \
       --tier $tier --type $parmtype $useprofile"
    aws ssm put-parameter --name $ssm_name --overwrite --value file://.$ssm_name \
       --tier $tier --type $parmtype $useprofile
  fi
}


#################################################################################
# Copyright Notice
# All Rights Reserved.
# All materials (the “Materials”) in this repository are protected by copyright 
# under U.S. Copyright laws and are the property of 2nd Sight Lab. They are provided 
# pursuant to a royalty free, perpetual license the person to whom they were presented 
# by 2nd Sight Lab and are solely for the training and education by 2nd Sight Lab.
#
# The Materials may not be copied, reproduced, distributed, offered for sale, published, 
# displayed, performed, modified, used to create derivative works, transmitted to 
# others, or used or exploited in any way, including, in whole or in part, as training 
# materials by or for any third party.
#
# The above copyright notice and this permission notice shall be included in all 
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, 
# INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A 
# PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT 
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION 
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE 
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
################################################################################  
