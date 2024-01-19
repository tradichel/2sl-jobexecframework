# 2sl-jobexecframework
2nd Sight Lab (2sl) Job Execution Framework

This is the core engine that runs jobs. The jobs are created in separate repositories so anyone can create a new job without altering this code.

For example, see these two repositories which have jobs that use this core code:

(2sl-job-awsorginit](https://github.com/tradichel/2sl-job-awsorginit) - the initial job run in a new AWS account when no resources exist.

[2sl-job-awsdeploy](https://github.com/tradichel/2sl-job-awsdeploy) - a job to deploy resources on AWS using a CloudFormation template and a job configuration that defines the parameters to pass into the template.

[2sl-jobconfig-awsdeploy](https://github.com/tradichel/2sl-jobconfig-awsdeploy) - a repository that contains jobs configured to deploy resources using the awsdeploy job (job-awsdeploy)

For example, the awsdepoy job can have many different jobs configured to run using that job container:

- Deploy an IAM role
- Deploy an AWS account
- Deploy a number of AWS accounts and OUs
- Deploy an environment
- Deploy an EC2 instance

There would be a separate job config for each of the above but they will all use the same container to deploy the resources (when I'm done).

Also, different containers can be created for different use cases. For example you might have jobs to do the following:

- Create an AWS AMI using Hashicorp Packer
- Assess the security of an AWS account (something I do with third party tools and tools I wrote)
- Deploy a GitHub repository
- Process data and genereate a report (another thing I do when performing penetration tests)
  
Each of those "jobs" can be executed multipe times with different configurations.

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
