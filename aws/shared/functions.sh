#!/bin/bash
# https://github.com/tradichel/SecurityMetricsAutomation
# Functions/shared_functions.sh
# author: @teriradichel @2ndsightlab
# WARNING: Bash is not a very safe language
# There is no scoping so if you use the same varname
# in multiple functions and you call both you can end up
# with overwritten values. Be careful.
##############################################################

replace_template_var(){
  local tmpfile="$1"
  local placeholder="$2"
  local value="$3"

  local func=${FUNCNAME[0]}
  validate_set $func 'tmpfile' $tmpfile
  validate_set $func 'placeholder' $placeholder
  validate_set $func 'value' $value

  #remove quotes from value
  local value=$(echo $value | sed "s/'//g" | sed 's/"//g')
  echo sed -i "s|{{$placeholder}}|$value|g" $tmpfile
  sed -i "s|{{$placeholder}}|$value|g" $tmpfile
  cat $tmpfile

}


configure_cli_profile(){
	local role="$1"
	local access_key_id="$2"
	local aws_secret_access_key="$3"
	local region="$4"
	local mfa_serial="$5"

	local output="json"

  local func=${FUNCNAME[0]}
  validate_set $func 'role' $role
  validate_set $func 'access_key_id' $access_key_id
  validate_set $func 'aws_secret_access_key' $aws_secret_access_key
	validate_set $func 'region' $region
	
	aws configure set aws_access_key_id $access_key_id --profile $role
	aws configure set aws_secret_access_key $aws_secret_access_key --profile $role
	aws configure set region $region --profile $role
	aws configure set output "json" --profile $role
	if [ "$mfa_serial" != "" ]; then
		aws configure set mfa_serial $mfa_serial --profile $role
	fi

	aws sts get-caller-identity --profile $role
	PROFILE=$role
}

get_region_for_PROFILE(){
  local f=${FUNCNAME[0]};validate_set $f 'PROFILE' $PROFILE;validate_set $f 'PROFILE' region
	local region=$(aws configure list --profile $PROFILE | grep region | awk '{print $2}')
	echo $region
}

get_account_for_PROFILE(){
  local f=${FUNCNAME[0]};validate_set $f 'PROFILE' $PROFILE;validate_set $f 'PROFILE' region
	local account=$(aws sts get-caller-identity --query Account --output text --profile $PROFILE)
	echo $account
}

get_stack_export(){

  local stackname=$1
  local exportname=$2

  local f=${FUNCNAME[0]};validate_set $f 'PROFILE' $PROFILE;validate_set $f 'PROFILE' region
  validate_set $f 'stackname' $stackname; validate_set $f 'exportname' $exportname

  local qry="Stacks[0].Outputs[?ExportName=='$exportname'].OutputValue"
  local value=$(aws cloudformation describe-stacks --stack-name $stackname --query $qry --output text \
		--profile $PROFILE --region $region)

  if [ "$value" == "" ]; then
    echo 'Export '$exportname' for stack '$stackname' did not return a value' 1>&2
    exit 1
  fi

  if [ "$value" == "None" ]; then
    echo 'Export '$exportname' for stack '$stackname' did not return a value' 1>&2
    exit 1
  fi

	echo $value

}


#get id from cloudforamtion stack
get_id_from_stack(){
	local role="$1"
	local resource_cat="$2"
	local resource_type="$3"
	local resource_name="$4"
	local env="$5"

  local resource="$resource_cat-$resource_type-$env-$resource_name"
  local stack="$role-$resource"
  local output="arn-$resource"

	local id=$(get_stack_export $stack $output)	
	echo $id

}

#get arn from cloudformation stack
get_arn_from_stack(){
  local role="$1"
  local resource_cat="$2"
  local resource_type="$3"
  local resource_name="$4"
  local env="$5"

	local resource="$resource_cat-$resource_type-$env-$resource_name"
	local stack="$role-$resource"
	local output="arn-$resource"

  local arn=$(get_stack_export $stack $output)        
  echo $arn
}

get_stack_status() {

	local stackname="$1"
  local f=${FUNCNAME[0]};validate_set $f 'PROFILE' $PROFILE;validate_set $f 'PROFILE' region
  validate_set $f 'stackname' $stackname

  echo $(aws cloudformation describe-stacks --stack-name $stackname --region $region \
     --query Stacks[0].StackStatus --output text --profile $PROFILE 2>/dev/null || true) 

}

display_stack_errors(){
	local stackname="$1"

  local f=${FUNCNAME[0]};validate_set $f 'PROFILE' $PROFILE;validate_set $f 'PROFILE' region
	validate_set $f 'stackname' $stackname
	
	aws cloudformation describe-stack-events --stack-name $stackname --max-items 5 \
		--region $region --profile $PROFILE | grep -i "status"
}

#get the role that is making the call to deploy something
get_sts_role_name(){
  local f=${FUNCNAME[0]};validate_set $f 'PROFILE' $PROFILE;validate_set $f 'PROFILE' region

	#rolenames cannot start with a letter or the stack name will fail.
  local role=$(aws sts get-caller-identity --region $region --profile $PROFILE --output text --query Arn | cut -d '/' -f2)
	echo $role
}

get_sts_role_arn(){
	local f=${FUNCNAME[0]};validate_set $f 'PROFILE' $PROFILE;validate_set $f 'PROFILE' region
 
 	#rolenames cannot start with a letter or the stack name will fail.
  local role=$(aws sts get-caller-identity --profile $PROFILE --region $region --output text --query Arn)
  echo $role
}

#add parameter to the list for the 
#deploy_stack function (below)
add_parameter () {
  local paramkey=$1
  local paramvalue=$2
  local addtoparams=$3

  func=${FUNCNAME[0]}
  validate_set $func "key" $paramkey
  validate_set $func "value" $paramvalue

  local addp="\"$paramkey=$paramvalue\""
  if [ "$addtoparams" == "" ]; then echo $addp; exit; fi
  echo $addtoparams,$addp

}


#REQUIREMENTS:
#must execute scripts from the directory containing the /resources and /deploy directories.
#must set the value of $PROFILE before calling this function
#pass in parameters in this format, with quotes:
#"key=value","key=value","key=value"
deploy_stack () {
  local resourcename="$1"
	local category="$2"
  local resourcetype="$3"
	local env="$4"
	local region="$5"
  local parameters="$6"
	local template="$7"

  local func=${FUNCNAME[0]}
  validate_set $func 'resourcename' $resourcename
  validate_set $func 'resourcetype' $resourcetype
  validate_set $func 'category' $category
  validate_set $func 'region' $region
  validate_set $func 'PROFILE' $PROFILE

	#usernames do not need to be prefixed with environment
	if [ "$resourcetype" == "user" ]; then
		echo "Deploying user: $user"
	else

		#kms key aliases start with alias/ because why? IDK
		if [ "$resourcetype" == "keyalias" ]; then
			local resourcename=$(echo $resourcename | cut -d "/" -f2)
		fi

		#the prefix before the dash should be the environment name
		local env=$(echo $resourcename | cut -d "-" -f1)
	
		#if the name is missing after "env-" throw an error
		if [ "$(echo $resourcename | cut -d "-" -f2)" == "" ];	then
			echo "Invalid resource name $resourcename" 1>&2
			exit 1
		fi
		
		#validate the environment variable is a valid value
		validate_environment $func $env $resourcename
	
	fi
 
	#resource name is template name if not overridden
	if [ "$template" == "" ]; then local template=$resourcetype'.yaml';fi
	
	if ! [[ "$template" =~ '/' ]]; then
		local template='resources/'$category'/'$resourcetype'/'$template
	fi

	#add parameters if any were passed in
  if [ "$parameters" != "" ]; then local parameters="[$parameters]"; fi
	
	#formulate the stack name
  local stackname=$PROFILE'-'$category'-'$resourcetype'-'$resourcename
	
	#get the status if the stack already exists
	local status=$(get_stack_status $stackname)

	#delete the stack if it already exists
	if [ "$status" == "ROLLBACK_COMPLETE" ]; then
		aws cloudformation delete-stack --stack-name $stackname --region $region --profile $PROFILE  
        while [ "$(get_stack_status $stackname)" == "DELETE_IN_PROGRESS" ]
        do
		sleep 5
		done
	fi

  echo "-------------- Deploying $stackname -------------------"

	local c="aws cloudformation deploy --profile $PROFILE 
			--stack-name $stackname --region $region
      --template-file $template"  
	
  #allowing IAM for all stacks; presume IAM Policies, SCPs, 
  #and Permission Boundaries will handle this, which is more appropriate
	local c=$c' --capabilities CAPABILITY_NAMED_IAM '

	if [ "$parameters" != "" ]; then 
  	  local c=$c' --parameter-overrides '$parameters
	fi

	echo "$c"
		
	local e="display_stack_errors $stackname $PROFILE"

  {	($c) } || { ($e) }	
}

get_timestamp() {

  local timestamp="$(date)"
  local timestamp=$(echo $timestamp | sed 's/ //g')
	echo $timestamp

}


#replace a var in {{ }}
replace_placeholder() {
	local name="$1"
	local value="$2"
	local file="$3"

  local s=$(sed -i "s|$name|$value|g" $file)
}

#get the current account ID where resources will be deployed
get_account_id(){
  local f=${FUNCNAME[0]};validate_set $f 'PROFILE' $PROFILE;validate_set $f 'PROFILE' region
  local acctid=$(aws sts get-caller-identity --query Account --output text --profile $PROFILE --region $region)
  echo $acctid
}

#get_account_number moved to account_functions.sh

get_current_region(){
	echo $(get_PROFILE_region)
}

get_PROFILE_region(){
   local region=$AWS_DEFAULT_REGION
 
   local f=${FUNCNAME[0]};validate_set $f 'PROFILE' $PROFILE;validate_set $f 'PROFILE' region

	 if [ "$region" == "" ]; then 
	 	 local region=$(aws configure get region --profile $PROFILE)	
	 fi
	 echo $region
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
                                                                                     
