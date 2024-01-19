# 2sl-jobexecframework
2nd Sight Lab (2sl) Job Execution Framework

# Benefits of this framework

* An organization can have an approved set of templates that can be used to deploy resources to help prevent misconfigurations.
* Cloud users can quickly configure new jobs without requiring additional approval if they are using defined templates.
* Organizations can enforce segregation of duties allowing only certain people to run certain jobs or change certain code.
* The framework enforces a naming convention for CloudFormation stacks, session names in CloudTrail and other resources.
* A standard naming convention simplifies policy enforcement, auditing, and security incident response.
* Use of [Micro-templates](https://medium.com/cloud-security/cloudformation-micro-templates-ae70236ae2d1) and the related beneifts.

# How it works
This repository contains the core engine that runs jobs. Containers that run jobs leverage this framework for core execution tasks.

The job-specific code exists in separate repositories so anyone can create a new job without altering this core code.

For example, see these two repositories which have jobs that use this core code:

[2sl-job-awsorginit](https://github.com/tradichel/2sl-job-awsorginit) - the initial job run in a new AWS account when no resources exist.

[2sl-job-awsdeploy](https://github.com/tradichel/2sl-job-awsdeploy) - a job to deploy resources on AWS using a CloudFormation template and a job configuration that defines the parameters to pass into the template.

The job configuration is in a separate repository from the job so people can add new job configurations without having access to the code that runs the job:

[2sl-jobconfig-awsdeploy](https://github.com/tradichel/2sl-jobconfig-awsdeploy) - a repository that contains jobs configured to deploy resources using the awsdeploy job (job-awsdeploy)

For example, the awsdeploy job might have the following different jobs configured to run using that job container:

- Deploy an IAM role
- Deploy an AWS account
- Deploy a number of AWS accounts and OUs
- Deploy an environment
- Deploy an EC2 instance

There would be a separate job config for each of the above but they can all use the same container to deploy resources.

Also, different containers can be created for different use cases. For example you might have jobs to do the following:

- Create an AWS AMI using Hashicorp Packer
- Assess the security of an AWS account (something I do with third party tools and tools I wrote)
- Deploy a GitHub repository
- Process data and genereate a report (another thing I do when performing penetration tests)
  
Each of those "jobs" can be executed multiple times with different configurations, for example in different accounts or environments or for different applications.

The explanation of how to use the framework in its latest iteration starts with this post:
[Separate Repositories for a Job Execution Framework, Job Images, and Job Configurations](https://medium.com/cloud-security/separate-repositories-for-a-job-execution-framework-job-images-and-job-configurations-77913e1c968d)

This code leverages code written in prior posts in the whole series which you can find here:
[Automating Cybersecurity Metrics](https://medium.com/cloud-security/automating-cybersecurity-metrics-890dfabb6198)

# How I earn a living:

Hire me for a penetration test by contacting me on LinkedIn: [Penetration Testing](https://2ndsightlab.com/cloud-penetration-testing.html)

Have a question? 
Schedule a call with me through [IANS Research](https://www.iansresearch.com/)

The code is not for sale of for commercial use. If you'd like to license
the proprietary inventions contact me for more information on LinkedIn: [Teri Radichel](https://linkedin.com/in/teriradichel)

Please read the License. 
Thank you!
