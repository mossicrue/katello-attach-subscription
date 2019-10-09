# katello-attach-subscription

automatically assign subscriptions to registered content-host on Satellite based on certain rules.
experimental branch, not so stable but daily updated.

## Description

`katello-attach-subscription` can be used to attach specific subscriptions to registered content-hosts in Satellite 6. It is needed when you have multiple subscriptions that can be given to your hosts but want a more granular assignment than done by default by Satellite 6. You could for example give a specific subscription to a set of hosts that match a common hostname pattern, submitted by a specific `virt-who` instance or matching a particular set of facts.

When run, `katello-attach-subscription` will execute the following steps:

* Parsing the subscriptions present in the yaml file
* Check the cluster status of the hypervisors, if requested, collecting data and printing reports
* Remove the subscriptions from the hypervisors without any guests, if requested
* Iterate and subscribe all the registered content hosts or the ones founded by the query passed in the configuration file

The subscription part is also divided in more simple parts that are:

* Attach all the facts data retrived by `--check-density` and `--virt-who options`, if present
* Search all the set of subscriptions present in the matching rules in the `:subs` entry of the configuration file
* If a set of subscriptions is found:
    * ensure that all of them are attached to the content host and attach the missing subscription
    * remove all the other that aren't expected from it
    * remove all the needed products that are attached as _dublicated_, eg 2 _"RHEL Premium"_ subscriptions when need 1
* If the checked content host is an Hypervisor, `katello-attach-subscription` will:
   * adding the guests of the hypervisor at the head of the hosts to subscribe
   * subscribe the guests, to avoid a _long subscription blackout_
   * return to the normal hosts queue

## Requirements

* [Ruby](https://www.ruby-lang.org/)
* [Apipie Bindings](https://github.com/Apipie/apipie-bindings)

## Options

* `-U`, `--uri=URI` URI to the Satellite, this must be https
* `-t`, `--timeout=TIMEOUT` Timeout for any API calls.
* `-u`, `--user=USER` User to log in to Satellite
* `-p`, `--pass=PASS` Password to log in to Satellite
* `-o`, `--organization-id=ID` ID of the Organization
* `-c`, `--config=FILE` configuration in YAML format
* `-n`, `--noop` do not actually execute anything
* `-s`, `--search=SEARCH` search for hosts matching this string only
* `--read-from-cache` use, if possible, cache file for subscriptions and hosts
* `--cache-file=FILE` set the cache file for reading and writing
* `--virt-who` run the command `virt-who --print` to retrieve hypervisor facts from virt-who data
* `--virt-who-file=FILE` set the cache file for reading and writing virt-who cache file
* `--empty-hypervisor` remove all the subscriptions from the hypervisors with no guests before assigning subs
* `--check-density` evaluate cluster data and set them as hypervisors facts. Print the cluster report in a file
* `--check-density-value=VALUE` set the custom value that will says if a cluster is "full" or "empty"
* `--check-density-file=FILE` set a custom name where the cluster report would be printed.
* `--print-subscription-report` print a report for the subscription used by the checked hosts
* `--print-subscription-report-file=FILE` set a custom name for the file where subscription report would be printed.
* `--multiple-search` allow to search content-hosts with the result of the query written in the yaml configuration file
* `--clean-same-product` ensure that all the content hosts has 1 subscriptions for every listed product in the rules present in the yaml
* `--host-auto-heal=VALUE` enable or disable hosts auto-heal process if VALUE is setted and different from noop
* `--repeat-API` allow to repeat API call for a certain number of time before fail
* `--max-step=MAX_STEP` set the max number of time a specific API call has to be repeated in case of fails
* `--repeat-API-sleep` add an incremental waiting time that is customizzable on yaml configuration file
* `--concurrency-mode` allow to run the code that assign subscription to every hosts in a concurrency way
* `-v`, `--verbose` show verbose output during the execution
* `-d`, `--debug` show debug code during execution

Some option descriptions wrote before aren't enough to explain how they work as they are a little complex.

### --check-density

With this options enabled, katello-attach-subscriopt will search for all the hypervisors registered on Satellite and group them by cluster, calculating for each cluster:

- Number of virtual guests
- Number of virtual guests with ELS OS
- Number of hypervisors
- Number of socket in the cluster
- VDCRatio, obtained by dividing `the number of virtual guests of a cluster` by `the number of socket of a cluster divided by 2`
- ELSRatio, obtained by dividing `the number of virtual guests with ELS OS of a cluster` by `the number of socket of a cluster divided by 2`

This data will be added in the `facts` dictionary of every fetched hypervisors during the assigning subscription phase with this schema and can be used in yaml configuration file as facts matcher rules

- `cluster_data::cluster_name`: name of the cluster
- `cluster_data::cluster_socket`: total number of socket in a cluster
- `cluster_data::cluster_hosts`: total number of hypervisor in a cluster
- `cluster_data::cluster_guests`: total number of virtual guests in a cluster
- `cluster_data::cluster_els_guests`: total number of virtual guests with an operative system that may need an ELS subscription
- `cluster_data::cluster_ratio`: VDCRatio, see explanation above
- `cluster_data::cluster_els_ratio`: ELSRatio, see explanation above

If the `--print-subscription-report` option is enabled there will be generated 2 CSV report, `cluster-state.csv` and `guest-report.csv`, containing all the data calculated before.

For check density options, in the configuration yaml are needed 2 variables:

- `:densityvalue` that set the border value of the VDCRatio: if the calculated `vdcratio` is >= of `:densityvalue` the cluster is in a good state for what is regarding the number of guests present in the cluster, otherwise is in a bad state.
- `:elsdensityvalue` that set the border value of the ELSRatio: if the calculated `elsratio` is >= of `:elsdensityvalue` the cluster is in a good state for what is regarding the number of guests with ELS OS, otherwise is in a bad state.

### --print-subscription-report

With this options enabled, katello-attach-subscription will generate some csv file that report data

- `cluster-state.csv` that contain a table with listed all the data gathered from the `--check-density` option
- `guest-report.csv` that contain a table that list, for every virtual guest, its name, the operative system, the hypervisor in which reside and the cluster in which reside the hypervisor
- `sub-report.csv` that show the entitlments and subscriptions expected and actual utilization for every subscriptions
- `detailed-report.csv` that show for every content-host which are the expected subscriptions with their expected used entitlment

Example of `sub-report.csv`

| Subscription Name | Expected Entitlement | Entitlement Available | Entitlement Consumed | Entitlement Free | State |
|-|-|-|-|-|-|
| Red Hat Enterprise Linux Server, Premium (Physical or Virtual Nodes) | 50 | 60 | 50 | 10 | OK |
| Red Hat Enterprise Linux for Virtual Datacenters, Premium | 20 | 10 | 10 | 0 | ERROR |

| Subscription Name | Instance Multiplier | Expected Subscription | Subscription Available | Subscription Consumed | Subscription Free | State |
|-|-|-|-|-|-|-|
| Red Hat Enterprise Linux Server, Premium (Physical or Virtual Nodes) | 2 | 25 | 30 | 25 | 5 | OK |
| Red Hat Enterprise Linux for Virtual Datacenters, Premium | 1 | 20 | 10 | 10 | 0 | ERROR |

### --host-auto-heal=VALUE

With this option enabled, `katello-attach-subscription` will manage the auto-heal process of every registered content-host.
The accepted value are currently 3:

- `noop` that will not change the current status of the auto-heal process of the content hosts
- `enable` that will enable the auto-heal process of the content hosts
- `disable` that will disable the auto-heal process of the content hosts

The auto-heal process of one content host ensure that the server has attached the subscriptions needed to cover the installed products.
If a server has a valid subscription status this process will don't do anything, instead, if a server has an invalid status it will search if there are any needed subscriptions available and attach it to the content host.

### --concurrency

With this option enabled, `katello-attach-subscription` will manage some parts of the code to run in _parallel_, reducing the execution time of it. The majors reasons that need this function are 2:

- Avoid that the script run for too much hours in a big environment
- Avoid that the [BZ 1667647](https://bugzilla.redhat.com/show_bug.cgi?id=1667647) impact too much.

The mandatory option to add in the `:settings` part of the configuration file is `:maxthread` value, it will set the maximum number of concurrent thread that will run at the same time.

The part of the code that will run in parallel are the hosts subscription part and the hypervisor's guests subscription part.
The first part will spawn as much threads as the one requested in the `:search` part of the configuration yaml.
If the number of requested thread are greater of the `:maxthread` value, the program will exit with error.

In the second part, after the hypervisor is subscribed, `katello-attach-subscription` will spawn the highest possible number of threads, dividing the guests list in _chunk_ of regular size.
Eg: 6 available threads that can be spawn, hypervisor with 30 guests: `katello-attach-subscription` will spawn 6 threads that will subscribe 5 guests for every thread.

## Configuration

`katello-attach-subscription` can be configured using an YAML file (`katello-attach-subscription.yaml` by default).

The configuration file consists of two mandatory sections: `settings` and `subs` and three optional sections: `search`, `sleep` and `variables`

The `settings` section allows to set the same details as the commandline options. Any options given on the command line will override the respective config file settings.

    :settings:
      :user: admin
      :pass: changeme
      :uri: https://localhost
      :org: 1
      :cachefile: 'katello-attach-subscription.cache'
      :verbose: true
      :virtwho: false

The `cachefile` is meant to run this program in a faster way because retrieving all of the systems can require huge time.
The `cachefile` will be written each time, while if `--use-cache` is specified on command line it will be readed and will skip systems extraction.

The `subs` section is an array of hashes which describe the subscriptions to be checked on the hosts.
Each subscription hash has a set of tests that a hosts had to pass:
* `hostname` is a mandatory entry that will be used as an regular expression to match the hostname of the content host in Katello.
* `type` is an optional entry that will be used to check if a hosts is an hypervisor, a physical server or a virtual one.
* `sub_layer` is an optional entry that will tell to kas what to do with the remaining rules after the hosts match for the first time. The possible values are:
  * `stop_parsing` if the hosts match the rules, the script will stop checking the remaining rules. Default value if not specified.
  * `keep_parsing` if the hosts match the rules, the script will continue checking the remaining rules, merging all the subscriptions the hosts will need.
  * `override` if the hosts match the rules, the previous fetched subscriptions would be replaced by the founded one. This value works as `keep_parsing`
* `facts` is an optional entry which contain an array of hashes that describe customizable tests for any content hosts facts. It is made up of three value that describe how to made the various tests.
  * `name` is the name of the facts that has to be checked
  * `value` is the value of the facts that has to be checked
  * `matcher` is the type of match that has to be done. The current match are:
    * `string` is a simple equal test from the hosts facts value and the value passed in yaml. Default value if not setted
    * `regex` check if the content hosts value match the regex created from the content of `value`
    * `vercmp` check if the hosts fact value pass the version comparsion specified in `value`

It also has a `sub` entry, which is an hash of value that would be searched through API
The hash has product as key, which is a string to identify the type of subscription, and the content is an array of query that found one or more contract of the subscriptions to be attached to the host.

    :subs:
      -
        hostname: esxi[0-9]\.example\.com
        sub:
          rhel:
            - 4543828edcf35158c30abc3554c1e36a
            - 5543828edcf35158c30abc3554c1e36b
          jboss:
            - 6543828edcf35158c30abc3554c1e36c
            - 7543828edcf35158c30abc3554c1e36d
          satellite:
            - 7543828edcf35158c30abc3554c1e36e
      -
        hostname: esxi123\.example\.com
        sub:
          rhel:
            - name: "Red Hat Enterprise Linux, Premium (Physical or Virtual Nodes)
        facts:
          - name: "virt::host_type"
          - value: "rhev|kvm|vmare"
          - matcher: "regex"

      -
        hostname: .*
        sub_layer: "keep_parsing"
        sub:
          rhel:
            - 4543828edcf35158c30abc3554c1e36a
        facts:
          - name: "cpu::cpu_socket(s)"
          - value: ">3"
          - matcher: "vercmp"

The `search` section could be an array of string or an array of hashes.

If using an array of string the use of concurrency it's not supported

    :search:
      - "hypervisor = true"
      - "name ~ nicehost0%.example.org"

Instead, if is used an array of hashes, it can be prompt to `katello-attach-subscription` which query is dedicated to which thread.

    :search:
      -
        query: "hypervisor = true"
        thread: "A"
      -
        query: "name ~ nicehost0%.example.org"
        thread: "B"

## Permissions

The following permissions are required to run `katello-attach-subscription`:

| Resource | Permissions |
|----------|-------------|
| Fact Value | view_facts|
| Host | view_hosts, edit_hosts|
| Organization | view_organizations|
| Subscription | view_subscriptions, attach_subscriptions, unattach_subscriptions|

## Caveats

Currently Satellite is not able to save fact that contain the socket number. Candlepin 2.0 (bug to be linked) and `Virt-who` 0.16 are needed `https://bugzilla.redhat.com/show_bug.cgi?id=1307024`.
Assumption that only 1 sub is needed is done currently.

### **INSTANCE_MULTIPLIER WORKAROUND [BZ 1664614](https://bugzilla.redhat.com/show_bug.cgi?id=1664614)** ###

Due to this bug, we had to do a manual check of the subscription to attach on the host in order to calculate the correct value of `instance_multiplier`.

**Description of problem:**

Output provided by this 2 Satellite API calls:

```
GET /katello/api/organizations/:organization_id/subscriptions/:id
GET /katello/api/subscriptions/:id
```

return `instance_multiplier` with value always set to **1**.

This is incorrect as subscriptions like *RHEL Premium for Physical or Virtual Nodes* requires to be attached with a quantity that is multiple of **2**.

The correct value is retrieved by calling ```GET /katello/api/organizations/:organization_id/subscriptions``` API passing as parameters:

```ruby
:available_for = "host"
:host_id = <the id of the host we need to attach>
```

or opening the **Subscription** page of one of the your listed products in the **Subscription Summary** of the **Access Portal of RedHat**.
If the value of **Instance Based** is **YES**, the subscriptions will have an **Instance Multiplier** of **2**, otherwise it would be of **1**.

The checked subscriptions are divided in these list as from result:

**A.** These subs has 1 as `instance_multiplier`

  - Virtual Datacenter Subscription that would be attached on an Hypervisor as:
    - *"Red Hat Enterprise Linux for Virtual Datacenters, Premium"*
    - *"Red Hat Enterprise Linux for Virtual Datacenters, Standard"*
    - *"Red Hat Enterprise Linux Extended Life Cycle Support (Unlimited Guests)"*
    - *"Smart Management for Unlimited Guests"*
  - Self-support subscriptions for physical or virtual nodes as
    - *"Red Hat Enterprise Linux Server Entry Level, Self-support"*,
    - *"Red Hat Enterprise Linux Server for HPC Compute Node, Self-support (1-2 sockets) (Up to 1 guest)"*
    - *"Smart Management for Red Hat Enterprise Linux Server for HPC Compute Node (Up to 1 guest)"*

**B.** These subs has 2 as `instance_multiplier`:

- *"Red Hat Enterprise Linux Server, Standard (Physical or Virtual Nodes)"*
- *"Red Hat Enterprise Linux Server, Premium (Physical or Virtual Nodes)"*
- *"Red Hat Enterprise Linux Extended Life Cycle Support (Physical or Virtual Nodes)"*
- *"Red Hat Gluster Storage, Standard (1 Physical or Virtual Node)"*
- *"Red Hat Gluster Storage, Premium (1 Physical or Virtual Node)"*
- *"Resilient Storage"*
- *"High Availability"*
- *"Smart Management"*
- *"90 Day Red Hat Enterprise Linux Server Supported Evaluation with Smart Management, Monitoring and all Add-Ons"*

The workaorund code simply checks if the host is **Physical** and need to attach one of the subscriptions in the B list, as only Physical servers may need instance_multiplier **2**.
**Hypervisor**'s subscriptions has `instance_multiplier` set to **1** and Virtual Guest need only **1** sub (fixed value)
