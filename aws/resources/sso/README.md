# There is no way to enforce MFA every time a role is assumed
# when using AWS SSO with the AWS CLI  at the time this code 
# base was written.
#
# I cannot use it well as a vendor in a cross-account capacity
# and enforce mfa and external ids
#
# I don't want to interact with a brower to obtain
# credentials which has a large attack surface
#
# Not using SSO for this reason; exploring Okta
#
# See IAM blog posts for other concerns or updates.
# 
# https://medium.com/cloud-security/aws-iam-932d6a043b7
############################################################
