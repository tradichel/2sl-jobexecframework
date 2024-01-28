#!/bin/bash -e
# https://github.com/tradichel/2sl-jobexecframework/
# awsdepoy/resources/organizations/account/account_functions.sh
# author: @teriradichel @2ndsightlab
# description: Functions to deploy accounts
##############################################################

source shared/functions.sh
source resources/organizations/organization/organization_functions.sh
source resources/organizations/organizationalunit/organizationalunit_functions.sh

get_account_ou(){
	accountid="$1"

  function=${FUNCNAME[0]}
  validate_var "$function" "accountid" "$accountid"

	ouid=$(aws organizations list-parents --child-id $accountid --output text --query 'Parents[0].Id' --profile $PROFILE)
	echo $ouid
}

move_account(){
	accountid="$1"
	ou_from="$2"
	ou_to="$3"

  function=${FUNCNAME[0]}
  validate_var $function "accountid" "$accountid"
  validate_var $fucntion "ou_from" "$ou_from"
  validate_var $function "ou_to" "$ou_to"

	echo "Move $accountid from $ou_from to $ou_to"
  aws organizations move-account --account-id $accountid --source-parent-id $ou_from --destination-parent-id $ou_to --profile $PROFILE
}

get_account_number_by_account_name_and_stack(){
  accountname=$1

  function=${FUNCNAME[0]}
  validate_var $function "accountname" "$accountname"
  
  stack='OrgRoot-Account-'$accountname
  exportname=$accountname'Account'
  acctnum=$(get_stack_export $stack $exportname)

  echo $acctnum
}

get_account_number_by_account_name(){
	get_account_number $1
}

get_account_number_from_account_name(){
	get_account_number $1
}

get_id(){
	account_name=$1

  function=${FUNCNAME[0]}
  validate_set $function "account_name" "$account_name"

	if  [ "$account_name" == "root" ] || [ "$account_name" == "master" ] || [ "$account_name" == "management_account" ]; then
		accountid=$(get_management_account_number)
	else
		accountid=$(aws organizations list-accounts \
		--query 'Accounts[?(Name == `'$account_name'` && Status == `ACTIVE`)].Id' \
		--output text \
		--profile $PROFILE)
  fi

	echo $accountid
}

create_account_alias(){
	alias="$1"
	account_PROFILE="$2"

	if [ "$account_PROFILE" == "" ]; then account_PROFILE=$PROFILE; fi

  function=${FUNCNAME[0]}
  validate_var $function "alias" "$alias"	

  aliascheck=$(aws iam list-account-aliases \
    --profile $account_PROFILE \
		--query AccountAliases[0] \
		--output text)

	if [ "$alias" != "" ]; then echo "Alias exists: $aliascheck"; exit; fi

	aws iam create-account-alias \
    --account-alias $alias \
		--profile $account_PROFILE

  aliascheck=$(aws iam list-account-aliases \
    --profile $account_PROFILE \
    --query AccountAliases[0] \
    --output text)

  echo "Account alias created: $aliascheck"

}


delete_account_alias(){
  alias="$1"
	account_PROFILE="$2"

  if [ "$account_PROFILE" == "" ]; then
    account_PROFILE=$PROFILE
  fi

  function=${FUNCNAME[0]}
  validate_var $function "alias" "$alias"              

  aws iam delete-account-alias \
    --account-alias $alias \
    --profile $account_PROFILE

	echo "Account alias deleted."
 
}

assume_organizations_role(){
	accountname="$1"

	#the necessary role is already assumed, so exit.
	if [ "$PROFILE" == "$accountname" ]; then exit; fi

	function=${FUNCNAME[0]}
	validate_set $function "accountname" $accountname
	validate_set $function "region" $region 
  validate_set $function "PROFILE" $PROFILE

	seconds=900
	
	env=$(echo $accountname | cut -d '-' -f1)
	orgrolename=$env'-adminrole'

	echo "Assume role: $orgrolename using PROFILE: $PROFILE"
	accountid=$(get_account_number_by_account_name $accountname)
	validate_set $function "accountid" $accountid

	session="$PROFILE-$accountname-$orgrolename"

	arn="arn:aws:iam::$accountid:role/$orgrolename"

	echo "#########################################"
	echo "Assume Organizations Role:"
	echo "Account ID: $accountid"
	echo "Account name: $accountname"
	echo "Role name: $orgrolename"
	echo "Role arn: $arn"
	echo "Session: $session"
	echo "#########################################"

	#echo get temporary credentials for $arn
	creds=$(aws sts assume-role \
	--role-arn $arn \
	--role-session-name $session \
	--profile $PROFILE \
 	--region $region \
  --duration-seconds $seconds)

	accesskeyid="$(echo $creds | jq -r ".Credentials.AccessKeyId")"
	secretaccesskey="$(echo $creds | jq -r ".Credentials.SecretAccessKey")"
	sessiontoken="$(echo $creds | jq -r ".Credentials.SessionToken")"

	validate_var "accesskeyid" $accesskeyid $function
	validate_var "secretaccesskey" $secretaccesskey $function
	
  echo "### Creating PROFILE for $accountname ###"
  aws configure set aws_access_key_id $accesskeyid --profile $accountname
  aws configure set aws_secret_access_key $secretaccesskey --profile $accountname
  aws configure set aws_session_token $sessiontoken --profile $accountname
  aws configure set region $region --profile $accountname
  aws configure set output "json" --profile $accountname
	
  #clear variables
  access_key=""
  secret_key=""
  session_token=""

	PROFILE=$accountname

  echo "### Created AWS CLI PROFILE: $accountname ###"
  aws sts get-caller-identity --profile $PROFILE
	
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
