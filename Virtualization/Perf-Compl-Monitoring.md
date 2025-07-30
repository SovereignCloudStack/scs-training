## IaaS Monitoring and Compliance

### OSISM manager management tools

See [Testbed Guide](https://docs.scs.community/docs/iaas/deployment-examples/testbed/usage)
or [Ciab Guide](https://docs.scs.community/docs/iaas/deployment-examples/cloud-in-a-box/#webinterfaces)
for a list of web-interfaces to manage your infrastructure.

#### Homer
A dashboard with links to the specific dashboards.

#### Netbox
IP address and asset management.

#### ARA
Ansible Runbook Records.

#### RabbitMQ
The queuing service between all OpenStack services.

#### phpMyAdmin
Database access.

#### Flower
Celery reconciler task queue.

#### Netdata
Live real-time monitoring.

### OpenStack Health Monitor (OSHM)

#### What it does
* OpenStack is a scenario test that was created ~9 years ago to simulate a
  customer deployment scenario that was claimed not t work correctly and
  attempted to reproduce the issue. The issue would only happen occasionally ...
    - Was written as bash script using openstack CLI
    - Runs many iterations to expose issue
* It has long outgrown its initial purpose
    - Lots of options to make deployment scenario more complex to trigger
      more exotic issues (that have been observed in real clouds though)
    - Records timing of commands and thus measures control plane performance
    - Has three minimal benchmarks (CPU, Net, Disk) to also record user performance
    - Data can be written to an influxdb (via telegraf) and visualized via grafana
    - Logic to clean up even in exotic error cases
* Unfortunately still a meanwhile overly complex shell script
    - Thus a successor project (using cucumber/gherkin) has been created which will
      in the future replace the old OSHM

#### Setup
* It is a snowflake setup: Create a driver VM in which you run the script
    - Actually you can run this from any machine that supports bash and openstack CLI
    - But we prefer to run it in the same cloud
        * Tests continue when external connectivity breaks
        * Monitor external connectivity via a different way (trivial)
    - Ideally you have a second OpenStack project where the resources under
      test are created, tested, cleaned up.
* Driver VM then also runs telegraf, influxdb, grafana
    - Log files are stored in file-system and are optionally pushed to Object Storage
    - Console output is optimized for readability (unlike log files), attach to it via `tmux attach`
    - Autostart realized via injecting keys into tmux ...
* Documentation at: <https://docs.scs.community/docs/operating-scs/guides/openstack-health-monitor/Debian12-Install>
    - Takes ~1hr to set up when doing for the first time

#### Dashboard
* Looking at 1 or 2 day views to understand the current state of your cloud
    - Use 30d or 6m for long-time trends
    - You can zoom in with the mouse
* Describing what you view:
    - Above the panels: Selecting cloud and filtering per resource, per service, ...  
      ![OSHM filtering](OSHM-1-Header.png)
    - First row: Gauges with errors and error rates  
      ![OSHM Summary Gauges](OSHM-2-Summary.png)
        * You should achieve 99.9% or better here
        * An occasional API error (2 per day or so) is not something to worry about
    - Second through fourth row: Errors  
      ![OSHM Error Stats](OSHM-3-Error-Stats.png)
        * This is the timeline for various kinds of errors
        * Ideally, it's all zero
    - Fifth through seventh row: Performance  
      ![OSHM Performance Stats](OSHM-4-Performance.png)
        * API performance, Resource wait times, Benchmark results
        * Resource waits: Some API calls (e.g. VM creation) return as soon as the parameters
          have been validated and the cloud start provisioning the resource. It can take
          some time which you want to monitor as well

#### OSHM and SCS certification
* Our compliance dashboard currently links the OSHM dashboards
    - This is not a requirement for achieving *SCS-compatible* certification
    - It will be a requirement for the upcoming *SCS-sovereign* certification
* It's best practice to have it and even share with the SCS community
    - Making quality transparent improves quality ...

### SCS Standards

#### Why standards?
* You can easily build cloud and container infrastructure from the same
  technologies that behaves very differently to the users.
    - Even more so if you are using different technologies
* This creates a hard technical lock-in
    - It takes serious effort to automate workloads for the automation
      capabilities of cloud platforms. Using the APIs correctly and
      taking the system behavior into account to create resilient
      deployments is an art that takes a lot of skills, labor and validation.
    - That investment needs to be redone if cloud behave differently
      or have different APIs.
* Very often, the differences add no meaningful customer value, just
  lock-in (= provider value)
* Compete with an large set of highly-compatible small/medium/large
  providers against the huge hyperscalers.
    - It's possible if you ignore the vast majority of platform services
    - These are only useful to a subset of users and result in hard to avoid
      lock-in

#### Standardization process
* It's an open collaborative democratic process
    - Governance by SCS project (until 2024) and now Forum SCS-Standards
      in OSBA (non-profit)
* Process defined by standard SCS-0001 <https://docs.scs.community/standards/scs-0001-v1-sovereign-cloud-standards>
    - Standards have a life-cycle (Draft, Stable, Obsolete) and are versioned
    - A subset of current stabilized standards is chosen to comprise *SCS-compatible IaaS*
      and *SCS-compatible KaaS*. These *certification scopes* are versioned as well.
* Standards come with one or several test cases that can be run manually or automatically
    - We have moved from github actions to a zuul pipeline to run the tests nightly
    - The (curated) results are visible in the compliance monitor
    - Test cases do not need admin privileges, so users can test clouds they have access to
    - In exceptional cases, the certification body (Forum SCS-Standards) may require documentation
      from the provider and can not (fully) test compliance.

#### Running tests manually
* The tests are all available on github where the standards live:
  In the <https://github.com/SovereignCloudStack/standards> repository. Tests are in the `Tests/` sub-directory.
* Running all IaaS tests: `./scs-compliance-check.py scs-compatible-iaas.yaml --subject=NAME -a os_cloud=CLOUD`
  assuming you have the cloud `CLOUD` defined in your `clouds.yaml` and `secure.yaml`.
* Running single tests: Navigate the directory structure:
    - `iaas/` for IaaS related tests
    - further subdirs for specific tests
* Most tests are python3 scripts
    - Many accept the `OS_CLOUD` environment variable to specify which cloud to test
    - Example: 

      ```bash
      garloff@framekurt(gxscs2-kaas2):volume-types [0]$ pwd
      /home/garloff/SCS/standards/Tests/iaas/volume-types
      garloff@framekurt(gxscs2-kaas2):volume-types [0]$ echo $OS_CLOUD
      gxscs2-kaas2
      garloff@framekurt(gxscs2-kaas2):volume-types [0]$ ./volume-types-check.py 
      WARNING: Recommendation violated: missing encrypted volume type
      WARNING: Recommendation violated: missing replicated volume type
      volume-types-check: PASS
      garloff@framekurt(gxscs2-kaas2):volume-types [0]$ 
      ```

    - Beyond the messages, the exit code is relevant. Here it's `0`, which is good.
      (My prompt is configured to display the exit code from the last command.)
    - Many checks do API calls without creating resources; the entropy test however
      boots a VM to perform some checks. More tests like this are expected in the
      future. Yet the SCS community tries to keep the required amount of resources
      (and thus the required quota) low.

#### Automated compliance tests
* <https://zuul.sovereignit.cloud> runs many jobs
    - CI checks triggered by github
    - Security pipeline
    - Dependency collection (SBOM)
    - Compliance checks (job: `scs-check-all`)
* The results of the compliance checks are collected by the compliance monitor
    - Failures are not immediately reported to avoid false positives
    - Instead case is reviewed by responsible engineer and reported to cloud provider
        * This avoids spurious (non-reproducible) failures to display non-compliance
        * It also gives CSPs an opportunity to get back into compliance quickly
        * Compliance engineer has also access to detailed log files
    * Curated results at: <https://compliance.sovereignit.cloud/page/table>
    * These are also mirrored at the docs page
* Approach the Forum SCS-Standards to get added to the list of tested clouds
    - Formal certification requires becoming member of the Forum SCS-Standards
        * This comes with a membership fee
        * You may pay the same fees without becoming member and received the entitlement to SCS certification


### Assignments Monitoring and Compliance

#### Compliance tests
* Run a single test against a test environment
    - Use our CiaB setup if you have no access to your own
* Run the complete compliance suite
    - Rerun it with high verbosity (debugging) enabled
* Find the compliance status of the tested SCS clouds on the public SCS web pages

#### OpenStack Health Monitor (30')
* Do this in pairs: Setup the OSHM
    - Find relevant docs page
    - Driver VM via GUI or by following instructions
    - Configure clouds.yaml ... and run a single iteration
    - Setup telegraf, influxdb, grafana
    - Bonus: Do the tmux autostart magic
    - Bonus2: Setup caddy for TLS/SSL access with LE certificate
