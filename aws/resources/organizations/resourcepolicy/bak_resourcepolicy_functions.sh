#!/bin/bash -e
# https://github.com/tradichel/SecurityMetricsAutomation
# awsdeploy/resources/organizations/resourcepolicy/resourcepolicy_functions.sh
# author: @teriradichel @2ndsightlab
# Description: Delegated admin for organizations (service control policies)
##############################################################


source shared/functions.sh
source shared/validate.sh
source resources/organizations/account/account_functions.sh

deploy_resourcepolicy() {

  resourcepolicyname="$1"
  env="$2"
	accountname="$3"

  function=${FUNCNAME[0]}
  validate_set "$function" "resourcepolicyname" "$resourcepolicyname"
	validate_set "$function" "accountname" "$accountname"
	validate_environment "$function" $env
  resourcepolicyname="$env-$resourcepolicyname"
	
	accountid=$(get_account_number "$accountname")

  parameters=$(add_parameter "NameParam" $resourcepolicyname)
  parameters=$(add_parameter "OrgPoliciesAdminAccountParam" $accountid $parameters)

  deploy_stack $resourcepolicyname "organizations" "resourcepolicy" $parameters

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
